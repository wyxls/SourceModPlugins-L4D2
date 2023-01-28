#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.4.0"
#define CVAR_FLAGS FCVAR_NOTIFY

#define MSGTAG "\x04[VoteManager]\x03"

#define VOTE_NONE 0
#define VOTE_POLLING 1
#define CUSTOM_ISSUE "#L4D_TargetID_Player"

char votes[][] =
{
	"veto",
	"pass",
	"cooldown_immunity",
	"custom",
	"returntolobby",
	"restartgame",
	"changedifficulty",
	"changemission",
	"changechapter",
	"changealltalk",
	"kick"
};

char filepath[PLATFORM_MAX_PATH];

ConVar hCreationTimer;
ConVar hCooldownMode;
ConVar hVoteCooldown;
ConVar hTankImmunity;
ConVar hRespectImmunity;
ConVar hLog;

int initVal;
int iCooldownMode;
float fVoteCooldown;
bool bTankImmunity;
bool bRespectImmunity;
int iLog;

int VoteStatus;
char sCaller[32];
char sIssue[128];
char sOption[128];
char sCmd[192];

enum VoteManager_Vote
{
	Voted_No = 0,
	Voted_Yes,
	Voted_CantVote,
	Voted_CanVote
};

bool bCustom;
bool bLeft4Dead2;
int iCustomTeam;
VoteManager_Vote iVote[MAXPLAYERS + 1] = { Voted_CantVote, ... };
float iNextVote[MAXPLAYERS + 1];
float flLastVote;

public Plugin myinfo =
{
	name = "[L4D/2] Vote Manager",
	author = "McFlurry, Dosergen",
	description = "Vote manager for left 4 dead",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?p=1582772"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if( test == Engine_Left4Dead )
	{
		bLeft4Dead2 = false;
	}
	else if( test == Engine_Left4Dead2 )
	{
		bLeft4Dead2 = true;
	}
	else
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	CreateConVar("l4d2_votemanager_version", PLUGIN_VERSION, "Version of Vote Manager", CVAR_FLAGS|FCVAR_DONTRECORD);
    
	hCooldownMode = CreateConVar("l4d2_votemanager_cooldown_mode", "0", "0 = cooldown is shared 1 = cooldown is independant", CVAR_FLAGS, true, 0.0, true, 1.0);
	hVoteCooldown = CreateConVar("l4d2_votemanager_cooldown", "60.0", "Clients can call votes after this many seconds", CVAR_FLAGS, true, 0.0, true, 300.0);
	hTankImmunity = CreateConVar("l4d2_votemanager_tank_immunity", "1", "Tanks have immunity against kick votes", CVAR_FLAGS, true, 0.0, true, 1.0);
	hRespectImmunity = CreateConVar("l4d2_votemanager_respect_immunity", "1", "Respect admin immunity levels in kick votes (only when admin kicking admin)", CVAR_FLAGS, true, 0.0, true, 1.0);
	hLog = CreateConVar("l4d2_votemanager_log", "3", "1 = Log vote info to files 2 = Log vote info to server; add the values together if you want", CVAR_FLAGS, true, 0.0, true, 3.0);
    
	hCreationTimer = FindConVar("sv_vote_creation_timer");
	hCreationTimer.AddChangeHook(TimerChanged);
	
	GetCvars();
	
	hCooldownMode.AddChangeHook(ConVarChanged);
	hVoteCooldown.AddChangeHook(ConVarChanged);
	hTankImmunity.AddChangeHook(ConVarChanged);
	hRespectImmunity.AddChangeHook(ConVarChanged);
	hLog.AddChangeHook(ConVarChanged);
	
	AutoExecConfig(true, "l4d_vote_manager");

	AddCommandListener(VoteStart, "callvote");
	AddCommandListener(VoteAction, "Vote");
    
	RegConsoleCmd("sm_pass", Command_VotePassvote, "Pass a current vote");
	RegConsoleCmd("sm_veto", Command_VoteVeto, "Veto a current vote");
	RegConsoleCmd("sm_customvote", CustomVote, "Start a custom vote");

	if(bLeft4Dead2) 
	{
		HookUserMessage(GetUserMessageId("VotePass"), VotePass_2);
		HookUserMessage(GetUserMessageId("VoteFail"), VoteFail_2);
	}
	else	
	{
		HookEvent("vote_passed", VotePass);
		HookEvent("vote_failed", VoteFail);
	}
	HookEvent("round_start", eRoundStart);

	BuildPath(Path_SM, filepath, sizeof(filepath), "logs/vote_manager.log");
   
	LoadTranslations("l4d_vote_manager.phrases");
}

public void TimerChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	hCreationTimer.SetInt(0);
}

public void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	initVal = hCreationTimer.IntValue;
	iCooldownMode = hCooldownMode.IntValue;
	fVoteCooldown = hVoteCooldown.FloatValue;
	bTankImmunity = hTankImmunity.BoolValue;
	bRespectImmunity = hRespectImmunity.BoolValue;
	iLog = hLog.IntValue;
}

public void eRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	hCreationTimer.SetInt(0);
	VoteStatus = VOTE_NONE;
	bCustom = false;
}

public void OnPluginEnd()
{
	hCreationTimer.SetInt(initVal);
}

public void OnClientDisconnect(int client)
{
	if(IsFakeClient(client))
	{
		return;
	}
	int userid = GetClientUserId(client);
	CreateTimer(5.0, TransitionCheck, userid);
	iVote[client] = Voted_CantVote;
	VoteManagerUpdateVote();
}

public Action TransitionCheck(Handle Timer, any userid)
{
	int client = GetClientOfUserId(userid);
	if(client == 0)
	{
		iNextVote[client] == 0.0;
	}
	return Plugin_Stop;
}

public Action CustomVote(int client, int args)
{
	if(GetServerClientCount(true) == 0)
	{
		return Plugin_Handled;
	}
	float flEngineTime = GetEngineTime();
	if((ClientHasAccess(client, "cooldown_immunity") || iNextVote[client] <= flEngineTime) && VoteStatus == VOTE_NONE && args >= 2 && ClientHasAccess(client, "custom"))
	{
		char arg1[5];
		GetCmdArg(1, arg1, sizeof(arg1));
		GetCmdArg(2, sOption, sizeof(sOption));
		if(args == 3)
		{
			GetCmdArg(3, sCmd, sizeof(sCmd));
		}
		Format(sCaller, sizeof(sCaller), "%N", client);
		LogVoteManager("%T", "Custom Vote", LANG_SERVER, client, arg1, sOption, sCmd);
		VoteManagerNotify(client, "%s %t", MSGTAG, "Custom Vote", client, arg1, sOption, sCmd);
		VoteLogAction(client, -1, "'%L' callvote custom started for team: %s (issue: '%s' cmd: '%s')", client, arg1, sOption, sCmd);
		iCustomTeam = StringToInt(arg1);
		VoteManagerPrepareVoters(iCustomTeam);
		VoteManagerHandleCooldown(client);
		VoteStatus = VOTE_POLLING;
		flLastVote = flEngineTime;
		CreateTimer(0.1, CreateVote, client, TIMER_FLAG_NO_MAPCHANGE);
		return Plugin_Handled;
	}
	return Plugin_Handled;
}

public Action VoteAction(int client, const char[] command, int argc)
{
	if(argc == 1 && iVote[client] == Voted_CanVote && client != 0 && VoteStatus == VOTE_POLLING)
	{
		char vote[5];
		GetCmdArg(1, vote, sizeof(vote));
		if(StrEqual(vote, "yes", false))
		{
			iVote[client] = Voted_Yes;
			VoteManagerUpdateVote();
			return Plugin_Continue;
		}
		else if(StrEqual(vote, "no", false))
		{
			iVote[client] = Voted_No;
			VoteManagerUpdateVote();
			return Plugin_Continue;
		}
	}
	return Plugin_Continue;
}

public Action VoteStart(int client, const char[] command, int argc)
{
	if(GetServerClientCount(true) == 0 || client == 0)
	{	
		return Plugin_Handled; // prevent votes while server is empty or if server tries calling vote
	}
	if(argc >= 1)
	{
		float flEngineTime = GetEngineTime();
		GetCmdArg(1, sIssue, sizeof(sIssue));
		if(argc == 2)
		{
			GetCmdArg(2, sOption, sizeof(sOption));
		}
		VoteStringsToLower();
		Format(sCaller, sizeof(sCaller), "%N", client);

		if((ClientHasAccess(client, "cooldown_immunity") || iNextVote[client] <= flEngineTime) && VoteStatus == VOTE_NONE)
		{
			if(flEngineTime-flLastVote <= 5.5) // minimum time that is required by the voting system itself before another vote can be called
			{
				return Plugin_Handled;
			}
			if(ClientHasAccess(client, sIssue))
			{
				if(StrEqual(sIssue, "custom", false))
				{
					ReplyToCommand(client, "%s %T", MSGTAG, "Use sm_customvote", client);
					return Plugin_Handled;
				}
				else if(StrEqual(sIssue, "kick", false))
				{
					return ClientCanKick(client, sOption);
				}
				else
				{
					if(argc == 2)
					{
						LogVoteManager("%T", "Vote Called 2 Arguments", LANG_SERVER, sCaller, sIssue, sOption);
						VoteManagerNotify(client, "%s %t", MSGTAG, "Vote Called 2 Arguments", sCaller, sIssue, sOption);
						VoteLogAction(client, -1, "'%L' callvote (issue '%s') (option '%s')", client, sIssue, sOption);
					}
					else
					{
						LogVoteManager("%T", "Vote Called", LANG_SERVER, sCaller, sIssue);
						VoteManagerNotify(client, "%s %t", MSGTAG, "Vote Called", sCaller, sIssue);
						VoteLogAction(client, -1, "'%L' callvote (issue '%s')", client, sIssue);
					}
				}
				VoteManagerPrepareVoters(0);
				VoteManagerHandleCooldown(client);

				VoteStatus = VOTE_POLLING;
				flLastVote = flEngineTime;

				return Plugin_Continue;
			}
			else
			{
				LogVoteManager("%T", "No Access", LANG_SERVER, sCaller, sIssue);
				VoteManagerNotify(client, "%s %t", MSGTAG, "No Access", sCaller, sIssue);
				VoteLogAction(client, -1, "'%L' callvote denied (reason 'no access')", client);
				ClearVoteStrings();
				return Plugin_Handled;
			}
		}
		else if(VoteStatus == VOTE_POLLING)
		{
			PrintToChat(client, "%s %T", MSGTAG, "Conflict", LANG_SERVER);
			VoteLogAction(client, -1, "'%L' callvote denied (reason 'vote already called')", client);
			ClearVoteStrings();
			return Plugin_Handled;
		}
		else if(iNextVote[client] > flEngineTime)
		{
			PrintToChat(client, "%s %T", MSGTAG, "Wait", LANG_SERVER, RoundToNearest(iNextVote[client]-flEngineTime));
			VoteLogAction(client, -1, "'%L' callvote denied (reason 'timeout')", client);
			ClearVoteStrings();
			return Plugin_Handled;
		}
		else
		{
			ClearVoteStrings();
			return Plugin_Handled;
		}
	}
	return Plugin_Handled; // if it wasn't handled up there I would start panicking
}

/*
structure
byte    team
byte    initiator
string  issue
string  option
string  caller
*/

public Action CreateVote(Handle Timer, any client)
{
	if(iCustomTeam == 0)
	{
		iCustomTeam = 255;
	}
	bCustom = true;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			if(iCustomTeam != 255)
			{
				int pteam = GetClientTeam(i);
				if(pteam != iCustomTeam)
				{
					continue;
				}
			}
			if(bLeft4Dead2)
			{ 
				BfWrite bf = UserMessageToBfWrite(StartMessageOne("VoteStart", i, USERMSG_RELIABLE));
				bf.WriteByte(iCustomTeam);
				bf.WriteByte(client);
				bf.WriteString(CUSTOM_ISSUE);
				bf.WriteString(sOption);
				bf.WriteString(sCaller);
				EndMessage();
			}
			else
			{	
				Event event = CreateEvent("vote_started");
				event.SetString("issue", CUSTOM_ISSUE);
				event.SetString("param1", sOption);
				event.SetString("param2", sCaller);
				event.SetInt("team", iCustomTeam);
				event.SetInt("initiator", client);
				event.Fire();
			}
			CreateTimer(float(GetConVarInt(FindConVar("sv_vote_timer_duration"))), CustomVerdict, _, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	VoteManagerSetVoted(client, Voted_Yes);
	VoteManagerUpdateVote();
	return Plugin_Stop;
}

public Action CustomVerdict(Handle Timer)
{
	if(!bCustom)
	{
		return Plugin_Stop;
	}
	int yes = VoteManagerGetVotedAll(Voted_Yes);
	int no = VoteManagerGetVotedAll(Voted_No);
	int numPlayers;
	int players[MAXPLAYERS + 1];
	bCustom = false;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && VoteManagerGetVoted(i) != Voted_CantVote)
		{
			if(iCustomTeam != 255)
			{
				int pteam = GetClientTeam(i);
				if(pteam != iCustomTeam)
				{
					continue;
				}
			}
			players[numPlayers] = i;
			numPlayers++;
		}
	}
	if(bLeft4Dead2)
	{
		if(yes > no)
		{
			LogVoteManager("%T", "Custom Passed", LANG_SERVER, sCaller, sOption);
			VoteLogAction(-1, -1, "sm_customvote (verdict: 'passed')");
			if(strlen(sCmd) > 0)
			{
				int client = GetClientByName(sCaller);
				if(client > 0)
				{
					FakeClientCommand(client, sCmd);
				}
				else if(client == 0)
				{
					ServerCommand(sCmd);
				}
			}

			Handle bf = StartMessage("VotePass", players, numPlayers, USERMSG_RELIABLE);
			BfWriteByte(bf, iCustomTeam);
			iCustomTeam = 0;
			BfWriteString(bf, CUSTOM_ISSUE);
			char votepassed[128];
			Format(votepassed, sizeof(votepassed), "%T", "Custom Vote Passed", LANG_SERVER);
			BfWriteString(bf, votepassed);
			EndMessage();
		}
		else
		{
			LogVoteManager("%T", "Custom Failed", LANG_SERVER, sCaller, sOption);
			VoteLogAction(-1, -1, "sm_customvote (verdict: 'failed')");

			Handle bf = StartMessage("VoteFail", players, numPlayers, USERMSG_RELIABLE);
			BfWriteByte(bf, iCustomTeam);
			iCustomTeam = 0;
			EndMessage();
		}
		return Plugin_Stop;
	}
	else
	{
		if(yes > no)
		{
			LogVoteManager("%T", "Custom Passed", LANG_SERVER, sCaller, sOption);
			VoteLogAction(-1, -1, "sm_customvote (verdict: 'passed')");
			if(strlen(sCmd) > 0)
			{
				int client = GetClientByName(sCaller);
				if(client > 0)
				{
					FakeClientCommand(client, sCmd);
				}
				else if(client == 0)
				{
					ServerCommand(sCmd);
				}
			}
	 
			Event event = CreateEvent("vote_passed");
			event.SetInt("team", iCustomTeam);
			iCustomTeam = 0;
			event.SetString("issue", CUSTOM_ISSUE);
			char votepassed[128];
			Format(votepassed, sizeof(votepassed), "%T", "Custom Vote Passed", LANG_SERVER);
			event.SetString("param1", votepassed);
			event.Fire();
		}
		else
		{
			LogVoteManager("%T", "Custom Failed", LANG_SERVER, sCaller, sOption);
			VoteLogAction(-1, -1, "sm_customvote (verdict: 'failed')");
        
			Event event = CreateEvent("vote_failed");
			event.SetInt("team", iCustomTeam);
			iCustomTeam = 0;
			event.Fire();
		}
		return Plugin_Stop;
	}
}

/*
structure
byte    team
string  issue pass response string
string  option response string
*/
public Action VotePass_2(UserMsg msg_id, BfRead bf, const int[] players, int playersNum, bool reliable, bool init)
{
	LogVoteManager("%T", "Vote Passed", LANG_SERVER);
	VoteLogAction(-1, -1, "callvote (verdict 'passed')");
	ClearVoteStrings();
	VoteStatus = VOTE_NONE;
	return Plugin_Continue;
}

public void VotePass(Event event, const char[] name, bool dontBroadcast)
{
	LogVoteManager("%T", "Vote Passed", LANG_SERVER);
	VoteLogAction(-1, -1, "callvote (verdict 'passed')");
	ClearVoteStrings();
	VoteStatus = VOTE_NONE;
}

/* this simply indicates that the vote failed, team is stored in it
structure
byte    team
*/
public Action VoteFail_2(UserMsg msg_id, BfRead bf, const int[] players, int playersNum, bool reliable, bool init)
{
	LogVoteManager("%T", "Vote Failed", LANG_SERVER);
	VoteLogAction(-1, -1, "callvote (verdict 'failed')");
	ClearVoteStrings();
	VoteStatus = VOTE_NONE;
	return Plugin_Continue;
}

public void VoteFail(Event event, const char[] name, bool dontBroadcast)
{
	LogVoteManager("%T", "Vote Failed", LANG_SERVER);
	VoteLogAction(-1, -1, "callvote (verdict 'failed')");
	ClearVoteStrings();
	VoteStatus = VOTE_NONE;
}

public Action Command_VoteVeto(int client, int args)
{
	if(VoteStatus == VOTE_POLLING && ClientHasAccess(client, "veto"))
	{
		int yesvoters = VoteManagerGetVotedAll(Voted_Yes);
		int undecided = VoteManagerGetVotedAll(Voted_CanVote);
		if(undecided * 2 > yesvoters)
		{
			for(int i = 1; i <= MaxClients; i++)
			{
				VoteManager_Vote info = VoteManagerGetVoted(i);
				if(info == Voted_CanVote)
				{
					VoteManagerSetVoted(i, Voted_No);
				}
			}
		}
		else
		{
			LogVoteManager("%T", "Cant Veto", LANG_SERVER, client);
			ReplyToCommand(client, "%s %T", MSGTAG, "Cant Veto", LANG_SERVER, client);
			VoteLogAction(client, -1, "'%L' sm_veto ('not enough undecided players')", client);
			return Plugin_Handled;
		}
		LogVoteManager("%T", "Vetoed", LANG_SERVER, client);
		ReplyToCommand(client, "%s %T", MSGTAG, "Vetoed", LANG_SERVER, client);
		VoteLogAction(client, -1, "'%L' sm_veto ('allowed')", client);
		VoteStatus = VOTE_NONE;
		return Plugin_Handled;
	}
	else if(ClientHasAccess(client, "veto"))
	{
		ReplyToCommand(client, "%s %T", MSGTAG, "No Vote", LANG_SERVER);
		VoteLogAction(client, -1, "'%L' sm_veto ('no vote')", client);
		return Plugin_Handled;
	}
	return Plugin_Handled;
}

public Action Command_VotePassvote(int client, int args)
{
	if(VoteStatus == VOTE_POLLING && ClientHasAccess(client, "pass"))
	{
		int novoters = VoteManagerGetVotedAll(Voted_No);
		int undecided = VoteManagerGetVotedAll(Voted_CanVote);
		if(undecided * 2 > novoters)
		{
			for(int i = 1; i <= MaxClients; i++)
			{
				VoteManager_Vote info = VoteManagerGetVoted(i);
				if(info == Voted_CanVote)
				{
					VoteManagerSetVoted(i, Voted_Yes);
				}
			}
		}
		else
		{
			LogVoteManager("%T", "Cant Pass", LANG_SERVER, client);
			ReplyToCommand(client, "%s %T", MSGTAG, "Cant Pass", LANG_SERVER, client);
			VoteLogAction(client, -1, "'%L' sm_veto ('not enough undecided players')", client);
			return Plugin_Handled;
		}
		LogVoteManager("%T", "Passed", LANG_SERVER, client);
		ReplyToCommand(client, "%s %T", MSGTAG, "Passed", LANG_SERVER, client);
		VoteLogAction(client, -1, "'%L' sm_pass ('allowed')", client);
		VoteStatus = VOTE_NONE;
		return Plugin_Handled;
	}
	else if(ClientHasAccess(client, "pass"))
	{
		ReplyToCommand(client, "%s %T", MSGTAG, "No Vote", LANG_SERVER);
		VoteLogAction(client, -1, "'%L' sm_pass ('no vote')", client);
		return Plugin_Handled;
	}
	return Plugin_Handled;
}

/**
 * Get's a Clients index by using their name
 *
 * @param name      Player's name.
 * @return          Current Client index of that name. -1 if client not found.
 */
stock int GetClientByName(const char[] name)
{
	char iname[32];
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			Format(iname, sizeof(iname), "%N", i);
			if(StrEqual(name, iname, true))
			{
				return i;
			}
		}
	}
	Format(iname, sizeof(iname), "%N", 0); //check console last as a player could mask themselves as console
	if(StrEqual(name, iname, true))
	{
		return 0;
	}
	return -1;
}

/**
 * Checks if a client has access to a votetype retrieved from callvote command
 *
 * @param client    Player's index.
 * @param what      Votetype name.
 * @param maxlength size of what
 * @return          true if they do, false if they don't or it is not an existing vote type.
 */
stock bool ClientHasAccess(int client, const char[] what)
{
	if(!IsValidVoteType(what)) // this plugin has no idea what this vote is, prevent them from running this vote.
	{
		LogVoteManager("%T", "Client Exploit Attempt", LANG_SERVER, client, client, what);
		VoteLogAction(client, -1, "'%L' callvote exploit attempted (fake votetype: '%s')", client, what);
		return false;
	}
	return CheckCommandAccess(client, what, 0, true);
}

/**
 * Compares a list of valid votes against a given vote.
 *
 * @param what          Type of vote to check access for.
 * @return              true if the vote exists false else.
 */
stock bool IsValidVoteType(const char[] what)
{
	for(int i = 0; i < sizeof(votes); i++)
	{
		if(StrEqual(what, votes[i]))
		{
			return true;
		}
	}
	return false;
}

/**
 * Checks if a client can kick a certain userid.
 *
 * @param client        Client index of player that is attempting to kick.
 * @param userid        String containing the userid that we're checking if client can kick.
 * @return              Plugin_Handled if they aren't allowed to, Plugin_Continue if they are allowed.
 */
stock Action ClientCanKick(int client, const char[] userid)
{
	if(strlen(userid) < 1 || client == 0) // empty userid/console can't call votes
	{
		ClearVoteStrings();
		return Plugin_Handled;
	}

	int target = GetClientOfUserId(StringToInt(userid));
	int cTeam = GetClientTeam(client);

	if(0 >= target || target > MaxClients || !IsClientInGame(target) || IsFakeClient(target))
	{
		LogVoteManager("%T", "Invalid Kick Userid", LANG_SERVER, client, userid);
		VoteManagerNotify(client, "%s %t", MSGTAG, "Invalid Kick Userid", client, userid);
		VoteLogAction(client, -1, "'%L' callvote kick denied (reason: 'invalid userid<%d>')", client, StringToInt(userid));
		ClearVoteStrings();
		return Plugin_Handled;
	}

	if(bTankImmunity && IsPlayerAlive(target) && cTeam == 3)
	{
		char model[128];
		GetClientModel(target, model, sizeof(model));
		if (StrContains(model, "hulk", false) > 0)
		{
			LogVoteManager("%T", "Tank Immune Response", LANG_SERVER, client, target);
			VoteManagerNotify(client, "%s %t", MSGTAG, "Tank Immune Response", client, target);
			VoteLogAction(client, -1, "'%L' callvote kick denied (reason: '%L has tank immunity')", client, target);
			ClearVoteStrings();
			return Plugin_Handled;
		}
	}
		
	if(cTeam == 1)
	{
		LogVoteManager("%T", "Spectator Response", LANG_SERVER, client, target);
		VoteManagerNotify(client, "%s %t", MSGTAG, "Spectator Response", client, target);
		VoteLogAction(client, -1, "'%L' callvote kick denied (reason: 'spectators have no kick access')", client);
		ClearVoteStrings();
		return Plugin_Handled;
	}

	AdminId id = GetUserAdmin(client);
	AdminId targetid = GetUserAdmin(target);

	if(bRespectImmunity && id != INVALID_ADMIN_ID && targetid != INVALID_ADMIN_ID) // both targets need to be admin.
	{
		if(!CanAdminTarget(id, targetid))
		{
			LogVoteManager("%T", "Kick Vote Call Failed", LANG_SERVER, client, target);
			VoteManagerNotify(client, "%s %t", MSGTAG, "Kick Vote Call Failed", client, target);
			VoteLogAction(client, -1, "'%L' callvote kick denied (reason: '%L has higher immunity')", client, target);
			ClearVoteStrings();
			return Plugin_Handled;
		}
	}

	if(CheckCommandAccess(target, "kick_immunity", 0, true) && !CheckCommandAccess(client, "kick_immunity", 0, true))
	{
		LogVoteManager("%T", "Kick Immunity", LANG_SERVER, client, target);
		VoteManagerNotify(client, "%s %t", MSGTAG, "Kick Immunity", client, target);
		VoteLogAction(client, -1, "'%L' callvote kick denied (reason: '%L has kick vote immunity')", client, target);
		ClearVoteStrings();
		return Plugin_Handled;
	}

	LogVoteManager("%T", "Kick Vote", LANG_SERVER, client, target);
	VoteManagerNotify(client, "%s %t", MSGTAG, "Kick Vote", client, target);
	VoteLogAction(client, -1, "'%L' callvote kick started (kickee: '%L')", client, target);
	VoteManagerPrepareVoters(cTeam);
	VoteManagerHandleCooldown(client);
	VoteStatus = VOTE_POLLING;
	flLastVote = GetEngineTime();
	return Plugin_Continue;
}

/**
 * Adds the appropriate cooldown time to all clients.
 *
 * @param client      Client index that will have cooldown time added if cooldown mode is independant.
 * @noreturn
 */
stock void VoteManagerHandleCooldown(int client)
{
	float time = GetEngineTime();
	float cooldown = fVoteCooldown;
	switch(iCooldownMode)
	{
		case 0:
		{
			for(int i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i))
				{
					iNextVote[i] = time + cooldown;
				}
			}
			return;
		}
		case 1:
		{
			iNextVote[client] = time + cooldown;
			return;
		}
	}
}

/**
 * Updates a custom vote's info.
 *
 * @noreturn
 */
stock void VoteManagerUpdateVote()
{
	if(!bCustom)
	{
		return;
	}
	int undecided = VoteManagerGetVotedAll(Voted_CanVote);
	int yes = VoteManagerGetVotedAll(Voted_Yes);
	int no = VoteManagerGetVotedAll(Voted_No);
	int total = yes + no + undecided;
	Event event = CreateEvent("vote_changed", true);
	event.SetInt("yesVotes", yes);
	event.SetInt("noVotes", no);
	event.SetInt("potentialVotes", total);
	event.Fire();
	if(no == total || yes == total || yes + no == total)
	{
		CreateTimer(0.1, CustomVerdict, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

/**
 * Sets the VoteManager_Vote of a client
 *
 * @param client    Client index.
 * @param vote      VoteManager_Vote tag type, only Voted_Yes and Voted_No are supported.
 * @noreturn
 */
stock void VoteManagerSetVoted(int client, VoteManager_Vote vote)
{
	if(vote > Voted_Yes || client == 0)
	{
		return;
	}
	else
	{
		switch(vote)
		{
			case Voted_Yes:
			{
				FakeClientCommand(client, "Vote Yes");
			}
			case Voted_No:
			{
				FakeClientCommand(client, "Vote No");
			}
		}
		iVote[client] = vote;
	}
}

/**
 * Gets the VoteManager_Vote of a client
 *
 * @param client  Client index.
 * @return        VoteManager_Vote of client
 */
stock VoteManager_Vote VoteManagerGetVoted(int client)
{
	return iVote[client];
}

/**
 * Gets the amount of players who match the vote info
 *
 * @param vote  VoteManager_Vote tag type.
 * @return      Total players that match this VoteManager_Vote
 */
stock int VoteManagerGetVotedAll(VoteManager_Vote vote)
{
	int total;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(VoteManagerGetVoted(i) == vote)
		{
			total++;
		}
	}
	return total;
}

/**
 * Sets whether a client can vote in prepration for a vote
 *
 * @param team      Which team will be voting.
 * @noreturn
 */
stock void VoteManagerPrepareVoters(int team)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			if(team == 0)
			{
				iVote[i] = Voted_CanVote;
			}
			else if(GetClientTeam(i) == team)
			{
				iVote[i] = Voted_CanVote;
			}
		}
		else
		{
			iVote[i] = Voted_CantVote;
		}
	}
}

/**
 * Clears the vote related strings of data.
 *
 * @noreturn
 */
stock void ClearVoteStrings()
{
	Format(sIssue, sizeof(sIssue), "");
	Format(sOption, sizeof(sOption), "");
	Format(sCaller, sizeof(sCaller), "");
	Format(sCmd, sizeof(sCmd), "");
}

/**
 * Makes all vote strings lower case
 *
 * @noreturn
 */
stock void VoteStringsToLower()
{
	StringToLower(sIssue, strlen(sIssue));
	StringToLower(sOption, strlen(sOption));
}

/**
 * Clears the vote related strings of data.
 *
 * @param string        String to be made lower case
 * @param stringlength  How many cells have data. use strlen to get this.
 * @noreturn
 */
stock void StringToLower(char[] string, int stringlength)
{
	int maxlength = stringlength + 1;
	char[] buffer = new char[maxlength], sChar = new char[maxlength];
	Format(buffer, maxlength, string);

	for(int i; i <= stringlength; i++)
	{
		Format(sChar, maxlength, buffer[i]);
		if(strlen(buffer[i+1]) > 0)
		{
			ReplaceString(sChar, maxlength, buffer[i+1], "");
		}
		if(IsCharUpper(sChar[0]))
		{
			sChar[0] += 0x20;
			//CharToLower(char[0]); this fails for some reason
			Format(sChar, maxlength, "%s%s", sChar, buffer[i+1]);
			ReplaceString(buffer, maxlength, sChar, sChar, false);
		}
	}
	Format(string, maxlength, buffer);
}

/**
 * Get total number of clients on the server
 *
 * @filterbots  Filter bots in this count
 * @return      Number of clients total
 */
stock int GetServerClientCount(bool filterbots = false)
{
	int total;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			total++;
			if(IsFakeClient(i) && filterbots)
			{
				total--;
			}
		}
	}
	return total;
}

/**
 * Handles LogAction for Vote Manager
 *
 * @client      Client performing the action, 0 for server, or -1 if not applicable.
 * @target      Client being targetted, or -1 if not applicable.
 * @message     Message format.
 * @...         Message formatting parameters.
 * @noreturn
 */
stock void VoteLogAction(int client, int target, const char[] message, any ...)
{
	if(iLog < 2)
	{
		return;
	}
	char buffer[512];
	VFormat(buffer, sizeof(buffer), message, 4);
	LogAction(client, target, buffer);
}

/**
 * Notify all clients except calling client
 *
 * @client      Client who will not be notified as they are the caller
 * @message     Message format.
 * @...         Message formatting parameters.
 * @noreturn
 */
stock void VoteManagerNotify(int client, const char[] message, any ...)
{
	char buffer[192];
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && i != client && !IsFakeClient(i))
		{
			if(CheckCommandAccess(i, "notify", 0, true))
			{
				SetGlobalTransTarget(i);
				VFormat(buffer, sizeof(buffer), message, 3);
				PrintToChat(i, buffer);
			}
		}
	}
}

/**
 * Log to Vote Managers own file.
 *
 * @log         Message format.
 * @...         Message formatting parameters.
 * @noreturn
 */
stock void LogVoteManager(const char[] log, any ...)
{
	if(iLog < 1)
	{
		return;
	}
	char buffer[256], time[64];
	FormatTime(time, sizeof(time), "L %m/%d/%Y - %H:%M:%S");
	VFormat(buffer, sizeof(buffer), log, 2);
	Format(buffer, sizeof(buffer), "[%s] %s", time, buffer);
	File file = OpenFile(filepath, "a");
	if(file)
	{
		WriteFileLine(file, buffer);
		FlushFile(file);
		delete file;
	}
	else
	{
		LogError("%T", "Log Error", LANG_SERVER);
	}
}