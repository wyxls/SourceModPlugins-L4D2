#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PLUGIN_VERSION "2.2.1"
new melee[4096];
new Float:g_flMANextTime[64] = -1.0;
new Float:g_flMFsave[64] = 0.0;
new Float:g_flMFlasttime[64] = 0.0;
new g_flMFlastact[64] = 0;
new g_iMAEntid[64] = -1;
new g_iMAEntid_notmelee[64] = -1;
//this tracks the attack count, similar to twinSF
new g_iMAAttCount[64] = -1;
new g_iMFFrame[64] = 0;
new bool:g_bSurvivorisEnsnared[MAXPLAYERS+1];
new bool:g_bSurvivorisRidden[MAXPLAYERS+1];
new infectedid[MAXPLAYERS+1];
new reloading[MAXPLAYERS+1];
new g_GameInstructor[MAXPLAYERS+1];
new Float:melee_speed[MAXPLAYERS+1];
new Handle:cvar_ammo = INVALID_HANDLE;
new Handle:cvar_ammolower = INVALID_HANDLE;
new Handle:cvar_ammoupper = INVALID_HANDLE;
new Handle:TrieMeleeAmmoUpper = INVALID_HANDLE;
new Handle:TrieMeleeAmmoLower = INVALID_HANDLE;
new Handle:cvar_escapeammo = INVALID_HANDLE;
new Handle:cvar_notice = INVALID_HANDLE;
new Handle:cvar_maspeed = INVALID_HANDLE;
new Handle:cvar_lownotice = INVALID_HANDLE;
new Handle:cvar_lang = INVALID_HANDLE;
new Handle:cvar_MA = INVALID_HANDLE;
new Handle:cvar_MF = INVALID_HANDLE;
new Handle:cvar_MF_count = INVALID_HANDLE;
new Handle:cvar_MF_time = INVALID_HANDLE;
new Handle:cvar_pistol = INVALID_HANDLE;
new Handle:cvar_killammo = INVALID_HANDLE;
new Handle:cvar_IE = INVALID_HANDLE;
new ammod;
new ammolowerd;
new ammoupperd;

new escapeammod;
new noticed;
new Float:maspeedd;
new lownoticed;
new langd;
new MAd;
new MFd;
new MF_countd;
new Float: MF_timed;
new pistold;
new killammod;
new IEd;
new g_ActiveWeaponOffset,g_iNextPAttO;
new bool:g_bIsLoading;
new g_iNextSAttO		= -1;
public Plugin:myinfo = 
{
	name = "L4D2 Melee  Mod",
	author = "hihi1210",
	description = "Melee weapons will breaks",
	version = PLUGIN_VERSION,
	url = ""
}

public OnPluginStart()
{

	decl String:s_Game[12];
	GetGameFolderName(s_Game, sizeof(s_Game));
	if (!StrEqual(s_Game, "left4dead2"))
	{
		SetFailState("L4D2 Melee  Mod will only work with Left 4 Dead 2!");
	}
	CreateConVar("sm_l4d2meleemod_version", PLUGIN_VERSION, "L4D2 Melee  Mod version", FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_DONTRECORD)
	HookEvent("item_pickup", Event_ItemPickup);
	cvar_ammo = CreateConVar("sm_l4d2meleemod_ammo_enable", "1", "Enable Melee Weapon ammo count",FCVAR_NOTIFY|FCVAR_NOTIFY);
	cvar_ammolower = CreateConVar("sm_l4d2meleemod_ammo_lower", "150", "After How many times of attack, the melee weapons breaks (default lower limit)",FCVAR_NOTIFY|FCVAR_NOTIFY);
	cvar_ammoupper = CreateConVar("sm_l4d2meleemod_ammo_upper", "250", "After How many times of attack, the melee weapons breaks (default upper limit)",FCVAR_NOTIFY|FCVAR_NOTIFY);
	cvar_notice = CreateConVar("sm_l4d2meleemod_notice", "2", "Show After how many attacks the melee weapon breaks ( 0 = disable ,1 = display numbers ,2 = bar",FCVAR_NOTIFY|FCVAR_NOTIFY);
	cvar_lownotice = CreateConVar("sm_l4d2meleemod_lownotice", "0", "Show a message when melee weapon nearly breaks",FCVAR_NOTIFY|FCVAR_NOTIFY);
	cvar_pistol = CreateConVar("sm_l4d2meleemod_pistol", "0", "after the melee weapon breaks , which secondary weapon will give out .(0: single pistol 1:double pistol 2:magnum 3:chainsaw",FCVAR_NOTIFY|FCVAR_NOTIFY);
	cvar_escapeammo = CreateConVar("sm_l4d2meleemod_ammo_escape", "100", "number of melee weapon ammo needed to escape from special infected",FCVAR_NOTIFY|FCVAR_NOTIFY);
	cvar_killammo = CreateConVar("sm_l4d2meleemod_ammo_kill", "150", "number of melee weapon ammo needed to kill special infected",FCVAR_NOTIFY|FCVAR_NOTIFY);
	cvar_IE = CreateConVar("sm_l4d2meleemod_infectedmode", "2", "0 = disable all 1 =allow escape infected 2 = allow kill infected 3=both allowed",FCVAR_NOTIFY|FCVAR_NOTIFY);
	cvar_MA = CreateConVar("sm_l4d2meleemod_MA", "2", "0 = close melee swing adjust 1 =global melee swing adjust(sm_l4d2meleemod_MA_interval + sm_setmelee) 2 = individual melee swing adjust( sm_setmelee )",FCVAR_NOTIFY|FCVAR_NOTIFY);
	cvar_maspeed =  CreateConVar("sm_l4d2meleemod_MA_interval", "0.3", "melee swing interval",FCVAR_NOTIFY|FCVAR_NOTIFY);
	cvar_MF =  CreateConVar("sm_l4d2meleemod_MF_enable", "1", "melee Fatigue enable(melee weapon)  sm_l4d2meleemod_MA must be 1 or 2",FCVAR_NOTIFY|FCVAR_NOTIFY);
	cvar_MF_count =  CreateConVar("sm_l4d2meleemod_MF_count", "12", "melee Fatigue start after ? number of swings (melee weapon)",FCVAR_NOTIFY|FCVAR_NOTIFY);
	cvar_MF_time =  CreateConVar("sm_l4d2meleemod_MF_time", "3.0", "melee Fatigue time (melee weapon)",FCVAR_NOTIFY|FCVAR_NOTIFY);
	cvar_lang = CreateConVar("sm_l4d2meleemod_language", "0", "0 = English , 1 = Traditional Chinese , 2= Simplified Chinese",FCVAR_NOTIFY|FCVAR_NOTIFY, true, 0.0, true, 2.0);
	HookConVarChange(cvar_ammo, ConVarChanged_cvar_ammo);
	HookConVarChange(cvar_ammolower, ConVarChanged_cvar_ammolower);
	HookConVarChange(cvar_ammoupper, ConVarChanged_cvar_ammoupper);
	HookConVarChange(cvar_notice, ConVarChanged_cvar_notice);
	HookConVarChange(cvar_lownotice, ConVarChanged_cvar_lownotice);
	HookConVarChange(cvar_pistol, ConVarChanged_cvar_pistol);
	HookConVarChange(cvar_escapeammo, ConVarChanged_cvar_escapeammo);
	HookConVarChange(cvar_killammo, ConVarChanged_cvar_killammo);
	HookConVarChange(cvar_IE, ConVarChanged_cvar_IE);
	HookConVarChange(cvar_MA, ConVarChanged_cvar_MA);
	HookConVarChange(cvar_maspeed, ConVarChanged_cvar_maspeed);
	HookConVarChange(cvar_MF, ConVarChanged_cvar_MF);
	HookConVarChange(cvar_MF_count, ConVarChanged_cvar_MF_count);
	HookConVarChange(cvar_MF_time, ConVarChanged_cvar_MF_time);
	HookConVarChange(cvar_lang, ConVarChanged_cvar_lang);
	HookEvent("weapon_fire", Event_WeaponFire, EventHookMode_Post);
	g_ActiveWeaponOffset = FindSendPropInfo("CBasePlayer", "m_hActiveWeapon");
	RegAdminCmd("sm_melee_upper", CmdSetMeleeUpper, ADMFLAG_CHEATS);
	RegAdminCmd("sm_melee_lower", CmdSetMeleeLower, ADMFLAG_CHEATS);
	RegAdminCmd("sm_melee_reset", CmdClearMeleeTrie, ADMFLAG_CHEATS);
	HookEvent("choke_start", Event_ChokeStart);
	HookEvent("lunge_pounce", Event_LungePounce);
	HookEvent("tongue_pull_stopped", event_Save);
	HookEvent("choke_stopped", event_Save);
	HookEvent("pounce_stopped", event_Save);
	HookEvent("jockey_ride_end", event_Save);
	HookEvent("charger_carry_end", event_Save);
	HookEvent("charger_pummel_end", event_Save);
	HookEvent("player_spawn", UnPwnUserid);
	HookEvent("player_death", UnPwnUserid);
	HookEvent("player_connect_full", UnPwnUserid);
	HookEvent("player_disconnect", UnPwnUserid);
	HookEvent("revive_success", UnPwnUserid1);
	HookEvent("jockey_ride", Event_JockeyRide);
	HookEvent("round_start", event_RoundStart);
	HookEvent("charger_pummel_start", Event_ChargerPummel);
	RegAdminCmd("sm_setmelee", Command_Setmelee, ADMFLAG_KICK, "Adjust melee speed!");
	g_iNextPAttO		=	FindSendPropInfo("CBaseCombatWeapon","m_flNextPrimaryAttack");
	g_iNextSAttO		=	FindSendPropInfo("CBaseCombatWeapon","m_flNextSecondaryAttack");
	g_bIsLoading = true;
	TrieMeleeAmmoUpper = CreateTrie();
	TrieMeleeAmmoLower = CreateTrie();
	AutoExecConfig(true, "l4d2_meleemod");
}

public OnMapStart()
{
	new max_entities = GetMaxEntities();

	for (new i = 0; i < max_entities; i++)
	{
		melee[i]= 0;
	}
}

public Action:CmdSetMeleeUpper(client, args)
{
	decl String:weapon[64], String:ammo[64];
	
	if (args == 2)
	{
		GetCmdArg(1, weapon, sizeof(weapon));
		GetCmdArg(2, ammo, sizeof(ammo));
		
		SetTrieValue(TrieMeleeAmmoUpper, weapon, StringToInt(ammo));
		if (langd == 0) 
		{
			ReplyToCommand(client, "Successfully set upper ammo of weapon: %s to %d!", weapon, StringToInt(ammo));
		}
		else if (langd == 1) 
		{
			ReplyToCommand(client, "成功將武器 %s 最高耐久為 %d!", weapon, StringToInt(ammo));
		}
		else if (langd == 2) 
		{
			ReplyToCommand(client, "成功将武器 %s 最高耐久为 %d!", weapon, StringToInt(ammo));
		}
	}
	else if (client)
	{
		decl String:weaponname[64];
		GetClientWeapon(client, weaponname, sizeof(weaponname));
		
		if (StrEqual(weaponname, "weapon_melee"))
		{
			GetEntPropString(GetPlayerWeaponSlot(client, 1), Prop_Data, "m_strMapSetScriptName", weaponname, sizeof(weaponname));
		}
		
		if (langd == 0) 
		{
			ReplyToCommand(client,"Usage: sm_melee_upper <weapon> <ammo> - your current weapon is %s", weaponname);
		}
		else if (langd == 1) 
		{
			ReplyToCommand(client,"用法: sm_melee_upper <武器名> <耐久(數字)> - 你現在使用 %s 中", weaponname);
		}
		else if (langd == 2) 
		{
			ReplyToCommand(client,"用法: sm_melee_upper <武器名> <耐久(数字)> - 你现在使用 %s 中", weaponname);
		}
	}
	else 
	{
		if (langd == 0) 
		{
			ReplyToCommand(client,"Usage: sm_melee_upper <weapon> <ammo> ");
		}
		else if (langd == 1) 
		{
			ReplyToCommand(client,"用法: sm_melee_upper <武器名> <耐久(數字)>");
		}
		else if (langd == 2) 
		{
			ReplyToCommand(client,"用法: sm_melee_upper <武器名> <耐久(数字)>");
		}
	}
	return Plugin_Handled;
}

public Action:CmdSetMeleeLower(client, args)
{
	decl String:weapon[64], String:ammo[64];
	
	if (args == 2)
	{
		GetCmdArg(1, weapon, sizeof(weapon));
		GetCmdArg(2, ammo, sizeof(ammo));
		
		SetTrieValue(TrieMeleeAmmoLower, weapon, StringToInt(ammo));
		if (langd == 0) 
		{
			ReplyToCommand(client, "Successfully set lower ammo of weapon: %s to %d!", weapon, StringToInt(ammo));
		}
		else if (langd == 1) 
		{
			ReplyToCommand(client, "成功將武器 %s 最低耐久為 %d!", weapon, StringToInt(ammo));
		}
		else if (langd == 2) 
		{
			ReplyToCommand(client, "成功将武器 %s 最低耐久为 %d!", weapon, StringToInt(ammo));
		}
	}
	else if (client)
	{
		decl String:weaponname[64];
		GetClientWeapon(client, weaponname, sizeof(weaponname));
		
		if (StrEqual(weaponname, "weapon_melee"))
		{
			GetEntPropString(GetPlayerWeaponSlot(client, 1), Prop_Data, "m_strMapSetScriptName", weaponname, sizeof(weaponname));
		}
		
		if (langd == 0) 
		{
			ReplyToCommand(client,"Usage: sm_melee_lower <weapon> <ammo> - your current weapon is %s", weaponname);
		}
		else if (langd == 1) 
		{
			ReplyToCommand(client,"用法: sm_melee_lower <武器名> <耐久(數字)> - 你現在使用 %s 中", weaponname);
		}
		else if (langd == 2) 
		{
			ReplyToCommand(client,"用法: sm_melee_lower <武器名> <耐久(数字)> - 你现在使用 %s 中", weaponname);
		}
	}
	else
	{
		if (langd == 0) 
		{
			ReplyToCommand(client,"Usage: sm_melee_lower <weapon> <ammo> ");
		}
		else if (langd == 1) 
		{
			ReplyToCommand(client,"用法: sm_melee_lower <武器名> <耐久(數字)>");
		}
		else if (langd == 2) 
		{
			ReplyToCommand(client,"用法: sm_melee_lower <武器名> <耐久(数字)>");
		}
	}
	return Plugin_Handled;
}

public Action:CmdClearMeleeTrie(client, args)
{
	ClearTrie(TrieMeleeAmmoUpper);
	ClearTrie(TrieMeleeAmmoLower);
	if (langd == 0) 
	{
		ReplyToCommand(client, "Cleared the ammo settings of all melee weapons,default values will be used!");
	}
	else if (langd == 1) 
	{
		ReplyToCommand(client, "已清除所有單獨格斗武器耐久設定");
	}
	else if (langd == 2) 
	{
		ReplyToCommand(client, "已清除所有单独格斗武器耐久设定");
	}
	return Plugin_Handled;
}

public Action:Command_Setmelee(client, Arguments)
{
	decl String:meleespeed[64];
	decl Float:meleespeedf;
	//Player:
	new Player;

	//Default:
	if(Arguments <= 1) return Plugin_Handled;

	//Retrieve Arguments:
	decl String:ArgumentName[32], String:PlayerName[32];

	//Initialize:
	GetCmdArg(1, ArgumentName, sizeof(ArgumentName));

	//Find:
	for(new X = 1; X <= GetMaxClients(); X++)
	{

		//Invalid:
		if(!IsClientConnected(X)) continue;

		//Initialize:
		GetClientName(X, PlayerName, sizeof(PlayerName));

		//Compare:
		if(StrContains(PlayerName, ArgumentName, false) != -1) Player = X;
	}
	if (Player <=0)
	{
		if (langd == 0) 
		{
			PrintToChat(client, "\x05[SM]Wrong Player Name");
		}
		else if (langd == 1) 
		{
			PrintToChat(client, "\x05[SM]玩家不存在");
		}
		else if (langd == 2) 
		{
			PrintToChat(client, "\x05[SM]玩家不存在");
		}
		return Plugin_Handled;
	}
	GetCmdArg(2, meleespeed, sizeof(meleespeed));
	meleespeedf = StringToFloat(meleespeed);
	if (meleespeedf <= 0.0)
	{
		meleespeedf =0.0;	
		melee_speed[Player] = meleespeedf;
		if (langd == 0) 
		{
			PrintToChat(client, "\x05[SM]Reseted %N to Normal speed", Player);
		}
		else if (langd == 1) 
		{
			PrintToChat(client, "\x05[SM]已將 %N 格斗速度回復正常", Player);
		}
		else if (langd == 2) 
		{
			PrintToChat(client, "\x05[SM]已将 %N 格斗速度回复正常", Player);
		}
		return Plugin_Handled;
	}
	melee_speed[Player] = meleespeedf;
	if (langd == 0) 
	{
		PrintToChat(client, "\x05[SM]Melee Speed of %N set to %f", Player, meleespeedf);
	}
	else if (langd == 1) 
	{
		PrintToChat(client, "\x05[SM]%N 的格斗速度改為 %f", Player, meleespeedf);
	}
	else if (langd == 2) 
	{
		PrintToChat(client, "\x05[SM]%N 的格斗速度改为 %f", Player, meleespeedf);
	}
	return Plugin_Handled;	
}

public OnClientPostAdminCheck(client)
{
	g_bSurvivorisEnsnared[client] = false;
	g_bSurvivorisRidden[client] = false;
	g_GameInstructor[client] = -1;
	melee_speed[client] = 0.0;
	reloading[client]=0;
	g_iMFFrame[client]=0;
}

public OnClientDisconnect(client)
{
	melee_speed[client] = 0.0;
}

public Action:MeleeCheck(client)
{
	if (ammod == 0) return;
	new Melee = GetPlayerWeaponSlot(client, 1);
	if (Melee > 0)
	{
		new String:sweapon[32];
		GetEdictClassname(Melee, sweapon, 32);
		if (StrContains(sweapon, "weapon_melee", false) >= 0)
		{
			if (IEd!=0)
			{
				if (IEd ==1 && melee[Melee] >= escapeammod || IEd ==2 && melee[Melee] >= killammod|| IEd ==3 && melee[Melee] >= killammod||IEd ==3 && melee[Melee] >= escapeammod)
				{
					QueryClientConVar(client, "gameinstructor_enable", ConVarQueryFinished:GameInstructor, client);
					ClientCommand(client, "gameinstructor_enable 1");
					CreateTimer(0.1, DisplayHint, client);
				}
			}
		}
	}
}

public Action:DisplayHint(Handle:h_Timer, any:client)
{
	decl i_Ent, String:s_TargetName[32], String:s_Message[256], Handle:h_Pack

	i_Ent = CreateEntityByName("env_instructor_hint")
	FormatEx(s_TargetName, sizeof(s_TargetName), "hint%d", client)

	new Melee = GetPlayerWeaponSlot(client, 1);
	if (IEd== 1 && melee[Melee] >= escapeammod)
	{
		if (langd == 0) 
		{
			FormatEx(s_Message, sizeof(s_Message), "You can press ATTACK2 button to use your melee weapon to escape!!!")
		}
		else if (langd == 1) 
		{
			FormatEx(s_Message, sizeof(s_Message), "您可以按推開鍵使用近戰武器逃跑!!!")
		}
		else if (langd == 2) 
		{
			FormatEx(s_Message, sizeof(s_Message), "您可以按推开键使用近战武器逃跑!!!")
		}
	}
	else if (IEd ==2 && melee[Melee] >= killammod)
	{
		if (langd == 0) 
		{
			FormatEx(s_Message, sizeof(s_Message), "You can press ATTACK button to use your melee weapon to kill the Special Infected!!!")
		}
		else if (langd == 1) 
		{
			FormatEx(s_Message, sizeof(s_Message), "您可以按攻擊鍵使用近戰武器擊殺特感!!!")
		}
		else if (langd == 2) 
		{
			FormatEx(s_Message, sizeof(s_Message), "您可以按攻击键使用近战武器击杀特感!!!")
		}
	}
	else if (IEd ==3 && melee[Melee] >= killammod && melee[Melee] >= escapeammod)
	{
		if (langd == 0) 
		{
			FormatEx(s_Message, sizeof(s_Message), "You can press ATTACK button to use your melee weapon to kill the Special Infected!!!\n You can press ATTACK2 button to use your melee weapon to escape!!!")
		}
		else if (langd == 1) 
		{
			FormatEx(s_Message, sizeof(s_Message), "您可以按攻擊鍵使用近戰武器擊殺特感!!! \n 您可以按推開鍵使用近戰武器逃跑!!!")
		}
		else if (langd == 2) 
		{
			FormatEx(s_Message, sizeof(s_Message), "您可以按攻击键使用近战武器击杀特感!!! \n 您可以按推开键使用近战武器逃跑!!!")
		}
	}
	else if (IEd ==3 && melee[Melee] >= killammod && melee[Melee] < escapeammod)
	{
		if (langd == 0) 
		{
			FormatEx(s_Message, sizeof(s_Message), "You can press ATTACK button to use your melee weapon to kill the Special Infected!!!")
		}
		else if (langd == 1) 
		{
			FormatEx(s_Message, sizeof(s_Message), "您可以按攻擊鍵使用近戰武器擊殺特感!!!")
		}
		else if (langd == 2) 
		{
			FormatEx(s_Message, sizeof(s_Message), "您可以按攻击键使用近战武器击杀特感!!!")
		}
	}
	else if (IEd ==3 && melee[Melee] >= escapeammod && melee[Melee] < killammod)
	{
		if (langd == 0) 
		{
			FormatEx(s_Message, sizeof(s_Message), "You can press ATTACK2 button to use your melee weapon to escape!!!")
		}
		else if (langd == 1) 
		{
			FormatEx(s_Message, sizeof(s_Message), "您可以按推開鍵使用近戰武器逃跑!!!")
		}
		else if (langd == 2) 
		{
			FormatEx(s_Message, sizeof(s_Message), "您可以按推开键使用近战武器逃跑!!!")
		}
	}
	DispatchKeyValue(client, "targetname", s_TargetName)
	DispatchKeyValue(i_Ent, "hint_target", s_TargetName)
	DispatchKeyValue(i_Ent, "hint_timeout", "5")
	DispatchKeyValue(i_Ent, "hint_range", "0.01")
	DispatchKeyValue(i_Ent, "hint_icon_onscreen", "use_binding")
	DispatchKeyValue(i_Ent, "hint_caption", s_Message)
	DispatchKeyValue(i_Ent, "hint_color", "255 255 255")
	DispatchKeyValue(i_Ent, "hint_binding", "+attack")
	DispatchSpawn(i_Ent)
	AcceptEntityInput(i_Ent, "ShowHint")
	PrintHintText(client,s_Message);
	h_Pack = CreateDataPack()
	WritePackCell(h_Pack, client)
	WritePackCell(h_Pack, i_Ent)
	CreateTimer(5.0, RemoveInstructorHint, h_Pack)
}

public GameInstructor(QueryCookie:q_Cookie, i_Client, ConVarQueryResult:c_Result, const String:s_CvarName[], const String:s_CvarValue[])
{
	g_GameInstructor[i_Client] = StringToInt(s_CvarValue);
}

public Action:RemoveInstructorHint(Handle:h_Timer, Handle:h_Pack)
{
	decl i_Ent, i_Client
	
	ResetPack(h_Pack, false)
	i_Client = ReadPackCell(h_Pack)
	i_Ent = ReadPackCell(h_Pack)
	CloseHandle(h_Pack)
	
	if (IsValidEntity(i_Ent))
	RemoveEdict(i_Ent)
	
	if (!g_GameInstructor[i_Client])
	ClientCommand(i_Client, "gameinstructor_enable 0")
}

public Action:Event_ChokeStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "victim"));
	if (victim == 0 || !IsClientInGame(victim) || IsFakeClient(victim)) return;
	new userid = GetClientOfUserId(GetEventInt(event, "userid"));
	infectedid[victim]=userid;
	g_bSurvivorisEnsnared[victim] = true;
	MeleeCheck(victim);
}

public Action:Event_LungePounce(Handle:event, const String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "victim"));
	if (victim == 0 || !IsClientInGame(victim) || IsFakeClient(victim)) return;
	new userid = GetClientOfUserId(GetEventInt(event, "userid"));
	infectedid[victim]=userid;
	g_bSurvivorisEnsnared[victim] = true;
	MeleeCheck(victim);
}

public Action:Event_JockeyRide(Handle:event, const String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "victim"));
	if (victim == 0 || !IsClientInGame(victim) || IsFakeClient(victim)) return;
	new userid = GetClientOfUserId(GetEventInt(event, "userid"));
	infectedid[victim]=userid;
	g_bSurvivorisEnsnared[victim] = true;
	g_bSurvivorisRidden[victim] = true;
	MeleeCheck(victim);
}

public Action:Event_ChargerPummel(Handle:event, const String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "victim"));
	if (victim == 0 || !IsClientInGame(victim) || IsFakeClient(victim)) return;
	new userid = GetClientOfUserId(GetEventInt(event, "userid"));
	infectedid[victim]=userid;
	g_bSurvivorisEnsnared[victim] = true;
	MeleeCheck(victim);
}

public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_WeaponEquip, OnWeaponEquip)
	infectedid[client]=-1;
}

public Action:Event_WeaponFire(Handle:event, const String:ename[], bool:dontBroadcast)
{
	if (ammod == 0) return;
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsClientInGame(client)) return;
	if (!IsPlayerAlive(client)) return;
	if (GetClientTeam(client) !=2) return;
	if (IsFakeClient(client)) return;
	if (IsPlayerIncapped(client)) return;
	new i_Weapon = GetEntDataEnt2(client, g_ActiveWeaponOffset)
	decl String:s_Weapon[32]
	if (IsValidEntity(i_Weapon))
	{
		GetEdictClassname(i_Weapon, s_Weapon, sizeof(s_Weapon))
		if (StrContains(s_Weapon, "weapon_melee", false) >= 0)
		{
			melee[i_Weapon]--;
			if (melee[i_Weapon] > 0)
			{
				if (melee[i_Weapon] == 15)
				{
					if (lownoticed == 1)
					{
						if (langd == 0) 
						{
							PrintHintText(client,"Your Melee Weapon nearly breaks");
						}
						else if (langd == 1) 
						{
							PrintHintText(client,"你的近戰武器快壞了");
						}
						else if (langd == 2) 
						{
							PrintHintText(client,"你的近战武器快坏了");
						}
					}
				}

				if (noticed == 1)
				{
					if (langd == 0) 
					{
						PrintHintText(client,"Melee Weapon strength: %d",melee[i_Weapon]);
					}
					else if (langd == 1) 
					{
						PrintHintText(client,"近戰武器耐久度: %d",melee[i_Weapon]);
					}
					else if (langd == 2) 
					{
						PrintHintText(client,"近战武器耐久度: %d",melee[i_Weapon]);
					}
				}
				else if (noticed == 2)
				{
					decl String:gauge[30] = "[====|=====|=====|====]";
					new Float:percent = float(melee[i_Weapon]) / float(ammoupperd);
					new pos = RoundFloat(percent * 20.0)+1;
					if (pos < 21)
					{
						gauge{pos} = ']';
						gauge{pos+1} = 0;
					}
					if (langd == 0) 
					{
						PrintHintText(client,"Melee Weapon strength: \n %s",gauge);
					}
					else if (langd == 1) 
					{
						PrintHintText(client,"近戰武器耐久度: \n %s",gauge);
					}
					else if (langd == 2) 
					{
						PrintHintText(client,"近战武器耐久度: \n %s",gauge);
					}
				}
			}
			else if (melee[i_Weapon] <=0)
			{
				melee[i_Weapon] = 0;
				RemoveEdict(i_Weapon);
				new String:command[] = "give";
				if (pistold == 0)
				{
					StripAndExecuteClientCommand(client, command, "pistol","","");
				}
				else if (pistold == 1)
				{
					StripAndExecuteClientCommand(client, command, "pistol","","");
					StripAndExecuteClientCommand(client, command, "pistol","","");
				}
				else if (pistold == 2)
				{
					StripAndExecuteClientCommand(client, command, "pistol_magnum","","");
				}
				else if (pistold == 3)
				{
					StripAndExecuteClientCommand(client, command, "chainsaw","","");
				}
				if (langd == 0) 
				{
					PrintHintText(client,"Your Melee Weapon Breaks!!!");
				}
				else if (langd == 1) 
				{
					PrintHintText(client,"你的近戰武器損壞了!!!");
				}
				else if (langd == 2) 
				{
					PrintHintText(client,"你的近战武器损坏了!!!");
				}
			}
		}
	}
}

public Action:Event_ItemPickup (Handle:event, const String:name[], bool:dontBroadcast)
{
	if (ammod == 0) return;
	new client = GetClientOfUserId( GetEventInt(event,"userid") );
	if ( !IsPlayerAlive(client) || GetClientTeam(client) == 3 ) return;
	new String:stWpn[24], String:stWpn2[32];
	GetEventString( event, "item", stWpn, sizeof(stWpn) );
	
	Format( stWpn2, sizeof( stWpn2 ), "weapon_%s", stWpn);
	if (StrContains(stWpn2, "weapon_melee", false) >= 0)
	{
		new Melee = GetPlayerWeaponSlot(client, 1);
		if (Melee > 0)
		{
			new String:sweapon[32];
			GetEdictClassname(Melee, sweapon, 32);
			if (StrContains(sweapon, "weapon_melee", false) >= 0)
			{
				if (melee[Melee] <= 0)
				{
					new String:meleename[32];
					new ammoupper;
					new ammolower;
					GetEntPropString(Melee, Prop_Data, "m_strMapSetScriptName", meleename, sizeof(meleename));
					if(GetTrieValue(TrieMeleeAmmoUpper, meleename, ammoupper) && GetTrieValue(TrieMeleeAmmoLower, meleename, ammolower))
					{
						new ammo = GetRandomInt(ammoupper, ammolower);
						melee[Melee] = ammo;
					}
					else
					{
						new ammo = GetRandomInt(ammolowerd, ammoupperd);
						melee[Melee] = ammo;
					}
				}
				if (melee[Melee] <= 15 && melee[Melee] > 0)
				{
					if (lownoticed == 1)
					{

						if (langd == 0) 
						{
							PrintHintText(client,"Your Melee Weapon nearly breaks");
						}
						else if (langd == 1) 
						{
							PrintHintText(client,"你的近戰武器快壞了");
						}
						else if (langd == 2) 
						{
							PrintHintText(client,"你的近战武器快坏了");
						}
					}
				}
			}
		}
	}
}

public Action:OnWeaponEquip(client, weapon)
{
	if (ammod == 0) return Plugin_Continue;
	if ( !IsPlayerAlive(client) || IsFakeClient(client) || GetClientTeam(client) == 3 )
	return Plugin_Continue;

	decl String:sWeapon[32];
	GetEdictClassname(weapon, sWeapon, sizeof(sWeapon));
	if (StrContains(sWeapon, "weapon_melee", false) >= 0)
	{
		if (weapon > 0)
		{
			if (melee[weapon] <= 0)
			{
				new String:meleename[32];
				new ammoupper;
				new ammolower;
				GetEntPropString(weapon, Prop_Data, "m_strMapSetScriptName", meleename, sizeof(meleename));
				if(GetTrieValue(TrieMeleeAmmoUpper, meleename, ammoupper) && GetTrieValue(TrieMeleeAmmoLower, meleename, ammolower))
				{
					new ammo = GetRandomInt(ammoupper, ammolower);
					melee[weapon] = ammo;
				}
				else
				{
					new ammo = GetRandomInt(ammolowerd, ammoupperd);
					melee[weapon] = ammo;
				}
			}
			if (melee[weapon] <= 15 && melee[weapon] > 0)
			{
				if (lownoticed == 1)
				{
					if (langd == 0) 
					{
						PrintHintText(client,"Your Melee Weapon nearly breaks");
					}
					else if (langd == 1) 
					{
						PrintHintText(client,"你的近戰武器快壞了");
					}
					else if (langd == 2) 
					{
						PrintHintText(client,"你的近战武器快坏了");
					}
				}
			}
		}
	}
	return Plugin_Continue;
}

StripAndExecuteClientCommand(client, String:command[], String:param1[], String:param2[], String:param3[])
{
	if(client == 0) return;
	if(!IsClientInGame(client)) return;
	if(IsFakeClient(client)) return;
	new admindata = GetUserFlagBits(client);
	new flags = GetCommandFlags(command);
	SetUserFlagBits(client, ADMFLAG_ROOT);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s %s %s", command, param1, param2, param3);
	SetCommandFlags(command, flags);
	SetUserFlagBits(client, admindata);
}

stock bool:IsPlayerIncapped(client)
{
	if (GetEntProp(client, Prop_Send, "m_isIncapacitated", 1)) return true;
	return false;
}

public Action:event_Save(Handle:event, const String:name[], bool:dontBroadcast)
{
	new Victim = GetClientOfUserId(GetEventInt(event, "victim"));
	if (Victim == 0 || !IsClientInGame(Victim) || IsFakeClient(Victim)) return;
	g_bSurvivorisEnsnared[Victim] = false;
	g_bSurvivorisRidden[Victim] = false;
	infectedid[Victim]=-1;
}

public UnPwnUserid (Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!client) return;
	g_bSurvivorisEnsnared[client] = false;
	g_bSurvivorisRidden[client] = false;
}

public UnPwnUserid1 (Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "subject"));
	if (!client) return;
	g_bSurvivorisEnsnared[client] = false;
	g_bSurvivorisRidden[client] = false;
}

public Action:OnPlayerRunCmd(client, &i_Buttons, &i_Impulse, Float:f_Velocity[3], Float:f_Angles[3], &i_Weapon)
{
	if (ammod == 0) return;
	if (IsFakeClient(client)) return;
	if (!IsPlayerAlive(client)) return;
	if (GetClientTeam(client) !=2) return;
	if (!g_bSurvivorisEnsnared[client]) return;
	if (IsPlayerIncapped(client)) return;
	if (IEd==2 || IEd==3)
	{
		if (i_Buttons & IN_ATTACK)
		{
			new Melee = GetPlayerWeaponSlot(client, 1);
			if (Melee > 0)
			{
				new String:sweapon[32];
				GetEdictClassname(Melee, sweapon, 32);
				if (StrContains(sweapon, "weapon_melee", false) >= 0)
				{
					if (melee[Melee] == killammod)
					{
						KillHIM(client);
						melee[Melee] = 0;
						CreateTimer(0.2,Timer_KillWeapon, client);
						CreateTimer(0.7,Timer_RestoreWeapon, client);
					}
					else if (melee[Melee] > killammod)
					{
						KillHIM(client);
						melee[Melee] = melee[Melee] - killammod;
						if (melee[Melee] <= 15)
						{
							if (langd == 0) 
							{
								PrintHintText(client, "You have killed the Special Infected using your melee weapon \n but your melee weapon nearly breaks!");
							}
							else if (langd == 1) 
							{
								PrintHintText(client,"你已使用近戰武器殺死特感 \n 但你的近戰武器快壞了");
							}
							else if (langd == 2) 
							{
								PrintHintText(client,"你已使用近战武器杀死特感 \n 但你的近战武器快坏了");
							}
						}
						else if (melee[Melee] > 15)
						{
							if (langd == 0) 
							{
								PrintHintText(client, "You have killed the Special Infected using your melee weapon \n but your melee weapon is damaged a bit!");
							}
							else if (langd == 1) 
							{
								PrintHintText(client,"你已使用近戰武器殺死特感 \n 但你的近戰武器損壞了一點");
							}
							else if (langd == 2) 
							{
								PrintHintText(client,"你已使用近战武器杀死特感 \n 但你的近战武器损坏了一点");
							}
						}
					}
					else
					{
						return;
					}
				}
			}
			return;
		}
	}
	if (IEd==1 || IEd==3)
	{
		if (i_Buttons & IN_ATTACK2)
		{
			new Melee = GetPlayerWeaponSlot(client, 1);
			if (Melee > 0)
			{
				new String:sweapon[32];
				GetEdictClassname(Melee, sweapon, 32);
				if (StrContains(sweapon, "weapon_melee", false) >= 0)
				{
					if (melee[Melee] == escapeammod)
					{
						SaveHIM(client);
						melee[Melee] = 0;
						RemoveEdict(Melee);
						CreateTimer(0.7,Timer_RestoreWeapon, client);
					}
					else if (melee[Melee] > escapeammod)
					{
						SaveHIM(client);
						melee[Melee] = melee[Melee] - escapeammod;
						if (melee[Melee] <= 15)
						{
							if (langd == 0) 
							{
								PrintHintText(client, "You have escaped using your melee weapon \n but your melee weapon nearly breaks!");
							}
							else if (langd == 1) 
							{
								PrintHintText(client,"你已使用近戰武器逃走 \n 但你的近戰武器快壞了");
							}
							else if (langd == 2) 
							{
								PrintHintText(client,"你已使用近战武器逃走 \n 但你的近战武器快坏了");
							}
						}
						else if (melee[Melee] > 15)
						{
							if (langd == 0) 
							{
								PrintHintText(client, "You have escaped using your melee weapon \n but your melee weapon is damaged a bit!");
							}
							else if (langd == 1) 
							{
								PrintHintText(client,"你已使用近戰武器逃走 \n 但你的近戰武器損壞了一點");
							}
							else if (langd == 2) 
							{
								PrintHintText(client,"你已使用近战武器逃走 \n 但你的近战武器损坏了一点");
							}
						}
					}
					else
					{
						return;
					}
				}
			}
			return;
		}
	}
}

public Action:SaveHIM(Client)
{
	// Check if its a valid player
	if (Client == 0 || !IsClientInGame(Client) || IsFakeClient(Client)) return;
	if (g_bSurvivorisEnsnared[Client])
	{
		SetConVarInt(FindConVar("director_no_death_check"), 1);
		if (g_bSurvivorisRidden[Client] == true)
		{
			SetEntData(Client, FindSendPropInfo("CTerrorPlayer", "m_isIncapacitated"), 1, 1, true);
		}
		else
		{
			SetEntData(Client, FindSendPropInfo("CTerrorPlayer", "m_lifeState"), 2, 1, true);
		}
		CreateTimer(1.0,Timer_RestoreState, Client);
		CallOnPummelEnded(Client);
		g_bSurvivorisEnsnared[Client] = false;
	}
}

public Action:KillHIM(Client)
{
	// Check if its a valid player
	if (Client == 0 || !IsClientInGame(Client) || IsFakeClient(Client)) return;
	if (g_bSurvivorisEnsnared[Client])
	{
		if (infectedid[Client] !=-1)
		{
			if (IsClientConnected(infectedid[Client]))
			{
				if (IsClientInGame(infectedid[Client]))
				{
					if (IsPlayerAlive(infectedid[Client]))
					{
						if (GetClientTeam(infectedid[Client]) ==3)
						{
							new Melee = GetPlayerWeaponSlot(Client, 1);
							new hp;
							hp= GetClientHealth(infectedid[Client]);
							new Float:valor = float(hp);
							SDKHooks_TakeDamage(infectedid[Client], Melee, Client, valor+1.0, DMG_CLUB, Melee, NULL_VECTOR, NULL_VECTOR);
							g_bSurvivorisEnsnared[Client] = false;
							g_bSurvivorisRidden[Client] = false;
							infectedid[Client] = -1;
						}
					}
				}
			}
		}
	}
}

public Action:Timer_RestoreState(Handle:timer, any:client)
{
	SetEntData(client, FindSendPropInfo("CTerrorPlayer", "m_isIncapacitated"), 0, 1, true);
	SetEntData(client, FindSendPropInfo("CTerrorPlayer", "m_lifeState"), 0, 1, true);
	ResetConVar(FindConVar("director_no_death_check"), true, true);
	if (g_bSurvivorisRidden[client] == true)
	g_bSurvivorisRidden[client] = false;
}

public Action:Timer_KillWeapon(Handle:timer, any:client)
{
	new Melee = GetPlayerWeaponSlot(client, 1);
	if (Melee > 0)
	{
		RemoveEdict(Melee);
	}
}

public Action:Timer_RestoreWeapon(Handle:timer, any:client)
{
	new String:command[] = "give";
	if (pistold == 0)
	{
		StripAndExecuteClientCommand(client, command, "pistol","","");
	}
	else if (pistold == 1)
	{
		StripAndExecuteClientCommand(client, command, "pistol","","");
		StripAndExecuteClientCommand(client, command, "pistol","","");
	}
	else if (pistold == 2)
	{
		StripAndExecuteClientCommand(client, command, "pistol_magnum","","");
	}
	else if (pistold == 3)
	{
		StripAndExecuteClientCommand(client, command, "chainsaw","","");
	}
	if (langd == 0) 
	{
		PrintHintText(client,"Your Melee Weapon Breaks!!!");
	}
	else if (langd == 1) 
	{
		PrintHintText(client,"你的近戰武器損壞了!!!");
	}
	else if (langd == 2) 
	{
		PrintHintText(client,"你的近战武器损坏了!!!");
	}
}

CallOnPummelEnded(client)
{
	static Handle:hOnPummelEnded=INVALID_HANDLE;
	if (hOnPummelEnded==INVALID_HANDLE)
	{
		new Handle:hConf = INVALID_HANDLE;
		hConf = LoadGameConfigFile("l4dl1d");
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CTerrorPlayer::OnPummelEnded");
		PrepSDKCall_AddParameter(SDKType_Bool,SDKPass_Plain);
		PrepSDKCall_AddParameter(SDKType_CBasePlayer,SDKPass_Pointer,VDECODE_FLAG_ALLOWNULL);
		hOnPummelEnded = EndPrepSDKCall();
		CloseHandle(hConf);
		infectedid[client]=-1;
		if (hOnPummelEnded == INVALID_HANDLE)
		{
			SetFailState("Can't get CTerrorPlayer::OnPummelEnded SDKCall!");
			return;
		}
	}
	SDKCall(hOnPummelEnded,client,true,-1);
}

public OnGameFrame()
{
	//if frames aren't being processed,
	//don't bother - otherwise we get LAG
	//or even disconnects on map changes, etc...
	
	if (IsServerProcessing()==false|| g_bIsLoading == true)return;
	if (MAd==1)
	{
		MA_OnGameFrame();
	}
	else if (MAd==2)
	{
		MA_OnGameFrame1();
	}
}

public OnMapEnd()
{	
	g_bIsLoading = true;
}

public event_RoundStart (Handle:event, const String:name[], bool:dontBroadcast)
{
	g_bIsLoading = false;
}

MA_OnGameFrame1()
{
	new speedcount = 0;
	if (MAd==0)
	return 0;
	new maxplayers = GetMaxClients();
	for (new i = 1; i <= maxplayers; i++)
	{
		if (i <= 0)continue;
		if(!IsClientInGame(i)) continue;
		speedcount++;
	}
	if (speedcount==0)
	return 0;
	decl iCid;
	//this tracks the player's ability id
	decl iEntid;
	//this tracks the calculated next attack
	decl Float:flNextTime_calc;
	//this, on the other hand, tracks the current next attack
	decl Float:flNextTime_ret;
	//and this tracks the game time
	new Float:flGameTime=GetGameTime();

	for (new iI=1; iI<=maxplayers; iI++)
	{
		//PRE-CHECKS 1: RETRIEVE VARS
		//---------------------------

		iCid = iI;
		//stop on this client
		//when the next client id is null
		if (iCid <= 0) continue;
		if(!IsClientInGame(iCid)) continue;
		if(!IsClientConnected(iCid)) continue; 
		if (!IsPlayerAlive(iCid)) continue;
		if(IsPlayerIncapped(iCid)) continue;
		if(GetClientTeam(iCid) != 2) continue;
		iEntid = GetEntDataEnt2(iCid,g_ActiveWeaponOffset);
		//if the retrieved gun id is -1, then...
		//wtf mate? just move on
		if (iEntid == -1) continue;
		//and here is the retrieved next attack time
		flNextTime_ret = GetEntDataFloat(iEntid,g_iNextPAttO);
		if (MFd == 1) 
		{
			if (g_flMFlastact[iCid] >=0)
			{
				if (g_flMFlastact[iCid] !=iEntid)
				{
					if ((g_flMFsave[iCid]-g_flMFlasttime[iCid]) >0)
					{
						if ((flGameTime - g_flMFlasttime[iCid])<(g_flMFsave[iCid]-g_flMFlasttime[iCid]) )
						{
							new Float:x =(g_flMFsave[iCid]-g_flMFlasttime[iCid])+flGameTime;
							decl String:ent_name[64];
							GetEdictClassname(iEntid, ent_name, sizeof(ent_name));
							if (StrContains(ent_name, "melee", false)!= -1)
							{
								SetEntDataFloat(iEntid, g_iNextPAttO, x, true);
							}
							SetEntDataFloat(iEntid, g_iNextSAttO, x, true);
							g_flMFlastact[iCid]=iEntid;
							reloading[iCid]=0;
						}
					}
				}
				if (GetEntProp(iEntid, Prop_Data, "m_bInReload")==1 && reloading[iCid]==0) 
				{
					reloading[iCid]=1;
					{
						if (iCid >0)
						{
							if ((g_flMFsave[iCid]-g_flMFlasttime[iCid]) >0)
							{
								if ((flGameTime - g_flMFlasttime[iCid])<(g_flMFsave[iCid]-g_flMFlasttime[iCid]) )
								{
									new Float:x =(g_flMFsave[iCid]-g_flMFlasttime[iCid])+flGameTime;
									SetEntDataFloat(iEntid, g_iNextSAttO, x, true);
									g_flMFlastact[iCid]=iEntid;
								}
							}
						}
					}
				}
				else if (GetEntProp(iEntid, Prop_Data, "m_bInReload")==1 && reloading[iCid]==1) 
				{
					reloading[iCid]=1;
				}
				else if (GetEntProp(iEntid, Prop_Data, "m_bInReload")==0 && reloading[iCid]==1)
				{
					reloading[iCid]=0;
					if (iCid >0)
					{
						if ((g_flMFsave[iCid]-g_flMFlasttime[iCid]) >0)
						{
							if ((flGameTime - g_flMFlasttime[iCid])<(g_flMFsave[iCid]-g_flMFlasttime[iCid]) )
							{
								new Float:x =(g_flMFsave[iCid]-g_flMFlasttime[iCid])+flGameTime;
								decl String:ent_name[64];
								GetEdictClassname(iEntid, ent_name, sizeof(ent_name));
								if (StrContains(ent_name, "melee", false)!= -1)
								{
									SetEntDataFloat(iEntid, g_iNextPAttO, x, true);
								}
								SetEntDataFloat(iEntid, g_iNextSAttO, x, true);
								g_flMFlastact[iCid]=iEntid;
							}
						}
					}
				}
				else if (GetEntProp(iEntid, Prop_Data, "m_bInReload")==0 && reloading[iCid]==0)
				{
					reloading[iCid]=0;
				}
				
			}
		}
		
		//----DEBUG----
		//PrintToChat(iCid,"\x03shove penalty \x01%i\x03, max penalty \x01%i",GetEntData(iCid,g_iMeleeFatigueO), g_iMA_maxpenalty);

		//CHECK 1: IS PLAYER USING A KNOWN NON-MELEE WEAPON?
		//--------------------------------------------------
		//as the title states... to conserve processing power,
		//if the player's holding a gun for a prolonged time
		//then we want to be able to track that kind of state
		//and not bother with any checks
		//checks: weapon is non-melee weapon
		//actions: do nothing
		if (iEntid == g_iMAEntid_notmelee[iCid])
		{
			//----DEBUG----
			//PrintToChatAll("\x03MA client \x01%i\x03; non melee weapon, ignoring",iCid );

			continue;
		}

		//CHECK 1.5: THE PLAYER HASN'T SWUNG HIS WEAPON FOR A WHILE
		//-------------------------------------------------------
		//in this case, if the player made 1 swing of his 2 strikes,
		//and then paused long enough, we should reset his strike count
		//so his next attack will allow him to strike twice
		//checks: is the delay between attacks greater than 1.5s?
		//actions: set attack count to 0, and CONTINUE CHECKS
		if (g_iMAEntid[iCid] == iEntid
				&& g_iMAAttCount[iCid]!=0
				&& (flGameTime - flNextTime_ret) > 1.0)
		{
			//----DEBUG----
			//PrintToChatAll("\x03MA client \x01%i\x03; hasn't swung weapon",iCid );

			g_iMAAttCount[iCid]=0;
		}

		//CHECK 2: BEFORE ADJUSTED ATT IS MADE
		//------------------------------------
		//since this will probably be the case most of
		//the time, we run this first
		//checks: weapon is unchanged; time of shot has not passed
		//actions: do nothing
		if (g_iMAEntid[iCid] == iEntid
				&& g_flMANextTime[iCid]>=flNextTime_ret)
		{
			//----DEBUG----
			//PrintToChatAll("\x03DT client \x01%i\x03; before shot made",iCid );

			continue;
		}

		//CHECK 3: AFTER ADJUSTED ATT IS MADE
		//------------------------------------
		//at this point, either a gun was swapped, or
		//the attack time needs to be adjusted
		//checks: stored gun id same as retrieved gun id,
		// and retrieved next attack time is after stored value
		//actions: adjusts next attack time
		if (g_iMAEntid[iCid] == iEntid && g_flMANextTime[iCid] < flNextTime_ret)
		{
			//----DEBUG----
			//PrintToChatAll("\x03DT after adjusted shot\n-pre, client \x01%i\x03; entid \x01%i\x03; enginetime\x01 %f\x03; NextTime_orig \x01 %f\x03; interval \x01%f",iCid,iEntid,flGameTime,flNextTime_ret, flNextTime_ret-flGameTime );
			if (MFd == 1) 
			{				
				g_iMAAttCount[iCid]++;
				if (g_iMAAttCount[iCid]>MF_countd)
				g_iMAAttCount[iCid]=1;
				if (g_iMAAttCount[iCid]==MF_countd)
				{
					flNextTime_calc = flGameTime + MF_timed ;

					//then we store the value
					g_flMANextTime[iCid] = flNextTime_calc;

					//and finally adjust the value in the gun
					SetEntDataFloat(iEntid, g_iNextPAttO, flNextTime_calc, true);
					SetEntDataFloat(iEntid, g_iNextSAttO, flNextTime_calc, true);
					g_flMFsave[iCid] =flNextTime_calc;
					g_flMFlasttime[iCid] =flGameTime;
					PrintHintText(iCid,"Melee Fatigue");
					//PrintToChatAll("\x03-post, NextTime_calc \x01 %f\x03; new interval \x01%f",GetEntDataFloat(iEntid,g_iNextPAttO), GetEntDataFloat(iEntid,g_iNextPAttO)-flGameTime );

					continue;
				}
				else
				{
					//this is a calculation of when the next primary attack
					//will be after applying double tap values
					//flNextTime_calc = ( flNextTime_ret - flGameTime ) * g_flMA_attrate + flGameTime;
					if (melee_speed[iCid] > 0.0)
					{
						flNextTime_calc = flGameTime + melee_speed[iCid] ;
						//then we store the value
						g_flMANextTime[iCid] = flNextTime_calc;

						//and finally adjust the value in the gun
						SetEntDataFloat(iEntid, g_iNextPAttO, flNextTime_calc, true);

						//----DEBUG----
						//PrintToChatAll("\x03-post, NextTime_calc \x01 %f\x03; new interval \x01%f",GetEntDataFloat(iEntid,g_iNextPAttO), GetEntDataFloat(iEntid,g_iNextPAttO)-flGameTime );

						continue;
					}
					else 
					{
						g_flMANextTime[iCid] = flNextTime_ret;
						continue;
					}
				}
			}
			else
			{
				//this is a calculation of when the next primary attack
				//will be after applying double tap values
				//flNextTime_calc = ( flNextTime_ret - flGameTime ) * g_flMA_attrate + flGameTime;
				if (melee_speed[iCid] > 0.0)
				{
					flNextTime_calc = flGameTime + melee_speed[iCid] ;
					//then we store the value
					g_flMANextTime[iCid] = flNextTime_calc;
					//and finally adjust the value in the gun
					SetEntDataFloat(iEntid, g_iNextPAttO, flNextTime_calc, true);
					//----DEBUG----
					//PrintToChatAll("\x03-post, NextTime_calc \x01 %f\x03; new interval \x01%f",GetEntDataFloat(iEntid,g_iNextPAttO), GetEntDataFloat(iEntid,g_iNextPAttO)-flGameTime );

					continue;
				}
				else 
				{
					g_flMANextTime[iCid] = flNextTime_ret;
					continue;
				}
			}
		}

		//CHECK 4: CHECK THE WEAPON
		//-------------------------
		//lastly, at this point we need to check if we are, in fact,
		//using a melee weapon =P we check if the current weapon is
		//the same one stored in memory; if it is, move on;
		//otherwise, check if it's a melee weapon - if it is,
		//store and continue; else, continue.
		//checks: if the active weapon is a melee weapon
		//actions: store the weapon's entid into either
		// the known-melee or known-non-melee variable

		//----DEBUG----
		//PrintToChatAll("\x03DT client \x01%i\x03; weapon switch inferred",iCid );

		//check if the weapon is a melee
		decl String:stName[32];
		GetEntityNetClass(iEntid,stName,32);
		if (StrEqual(stName,"CTerrorMeleeWeapon",false)==true)
		{
			//if yes, then store in known-melee var
			g_iMAEntid[iCid]=iEntid;
			g_flMANextTime[iCid]=flNextTime_ret;
			continue;
		}
		else
		{
			//if no, then store in known-non-melee var
			g_iMAEntid_notmelee[iCid]=iEntid;
			continue;
		}
	}

	return 0;
}

MA_OnGameFrame()
{
	new surbotcount = 0;
	if (MAd==0)
	return 0;
	new maxplayers = GetMaxClients();
	for (new i = 1; i <= maxplayers; i++)
	{
		if (i <= 0)continue;
		if(!IsClientInGame(i)) continue;
		surbotcount++;
	}
	//or if no one has DT, don't bother either
	if (surbotcount==0)
	return 0;

	decl iCid;
	//this tracks the player's ability id
	decl iEntid;
	//this tracks the calculated next attack
	decl Float:flNextTime_calc;
	//this, on the other hand, tracks the current next attack
	decl Float:flNextTime_ret;
	//and this tracks the game time
	new Float:flGameTime=GetGameTime();

	for (new iI=1; iI<=maxplayers; iI++)
	{
		//PRE-CHECKS 1: RETRIEVE VARS
		//---------------------------

		iCid = iI;
		//stop on this client
		//when the next client id is null
		if (iCid <= 0) continue;
		if(!IsClientInGame(iCid)) continue;
		if(!IsClientConnected(iCid)) continue; 
		if (!IsPlayerAlive(iCid)) continue;
		if(IsPlayerIncapped(iCid)) continue;
		if(GetClientTeam(iCid) != 2) continue;
		iEntid = GetEntDataEnt2(iCid,g_ActiveWeaponOffset);
		//if the retrieved gun id is -1, then...
		//wtf mate? just move on
		if (iEntid == -1) continue;
		//and here is the retrieved next attack time
		flNextTime_ret = GetEntDataFloat(iEntid,g_iNextPAttO);
		if (MFd == 1) 
		{
			if (g_flMFlastact[iCid] >=0)
			{
				if (g_flMFlastact[iCid] !=iEntid)
				{
					if ((g_flMFsave[iCid]-g_flMFlasttime[iCid]) >0)
					{
						if ((flGameTime - g_flMFlasttime[iCid])<(g_flMFsave[iCid]-g_flMFlasttime[iCid]) )
						{
							new Float:x =(g_flMFsave[iCid]-g_flMFlasttime[iCid])+flGameTime;
							decl String:ent_name[64];
							GetEdictClassname(iEntid, ent_name, sizeof(ent_name));
							if (StrContains(ent_name, "melee", false)!= -1)
							{
								SetEntDataFloat(iEntid, g_iNextPAttO, x, true);
							}
							SetEntDataFloat(iEntid, g_iNextSAttO, x, true);
							g_flMFlastact[iCid]=iEntid;
							reloading[iCid]=0;
						}
					}
				}
				if (GetEntProp(iEntid, Prop_Data, "m_bInReload")==1 && reloading[iCid]==0) 
				{
					reloading[iCid]=1;
					{
						if (iCid >0)
						{
							if ((g_flMFsave[iCid]-g_flMFlasttime[iCid]) >0)
							{
								if ((flGameTime - g_flMFlasttime[iCid])<(g_flMFsave[iCid]-g_flMFlasttime[iCid]) )
								{
									new Float:x =(g_flMFsave[iCid]-g_flMFlasttime[iCid])+flGameTime;
									SetEntDataFloat(iEntid, g_iNextSAttO, x, true);
									g_flMFlastact[iCid]=iEntid;
								}
							}
						}
					}
				}
				else if (GetEntProp(iEntid, Prop_Data, "m_bInReload")==1 && reloading[iCid]==1) 
				{
					reloading[iCid]=1;
				}
				else if (GetEntProp(iEntid, Prop_Data, "m_bInReload")==0 && reloading[iCid]==1)
				{
					reloading[iCid]=0;
					if (iCid >0)
					{
						if ((g_flMFsave[iCid]-g_flMFlasttime[iCid]) >0)
						{
							if ((flGameTime - g_flMFlasttime[iCid])<(g_flMFsave[iCid]-g_flMFlasttime[iCid]) )
							{
								new Float:x =(g_flMFsave[iCid]-g_flMFlasttime[iCid])+flGameTime;
								decl String:ent_name[64];
								GetEdictClassname(iEntid, ent_name, sizeof(ent_name));
								if (StrContains(ent_name, "melee", false)!= -1)
								{
									SetEntDataFloat(iEntid, g_iNextPAttO, x, true);
								}
								SetEntDataFloat(iEntid, g_iNextSAttO, x, true);
								g_flMFlastact[iCid]=iEntid;
							}
						}
					}
				}
				else if (GetEntProp(iEntid, Prop_Data, "m_bInReload")==0 && reloading[iCid]==0)
				{
					reloading[iCid]=0;
				}
				
			}
		}
		//----DEBUG----
		//PrintToChat(iCid,"\x03shove penalty \x01%i\x03, max penalty \x01%i",GetEntData(iCid,g_iMeleeFatigueO), g_iMA_maxpenalty);

		//CHECK 1: IS PLAYER USING A KNOWN NON-MELEE WEAPON?
		//--------------------------------------------------
		//as the title states... to conserve processing power,
		//if the player's holding a gun for a prolonged time
		//then we want to be able to track that kind of state
		//and not bother with any checks
		//checks: weapon is non-melee weapon
		//actions: do nothing
		if (iEntid == g_iMAEntid_notmelee[iCid])
		{
			//----DEBUG----
			//PrintToChatAll("\x03MA client \x01%i\x03; non melee weapon, ignoring",iCid );

			continue;
		}

		//CHECK 1.5: THE PLAYER HASN'T SWUNG HIS WEAPON FOR A WHILE
		//-------------------------------------------------------
		//in this case, if the player made 1 swing of his 2 strikes,
		//and then paused long enough, we should reset his strike count
		//so his next attack will allow him to strike twice
		//checks: is the delay between attacks greater than 1.5s?
		//actions: set attack count to 0, and CONTINUE CHECKS
		if (g_iMAEntid[iCid] == iEntid
				&& g_iMAAttCount[iCid]!=0
				&& (flGameTime - flNextTime_ret) > 1.0)
		{
			//----DEBUG----
			//PrintToChatAll("\x03MA client \x01%i\x03; hasn't swung weapon",iCid );

			g_iMAAttCount[iCid]=0;
		}

		//CHECK 2: BEFORE ADJUSTED ATT IS MADE
		//------------------------------------
		//since this will probably be the case most of
		//the time, we run this first
		//checks: weapon is unchanged; time of shot has not passed
		//actions: do nothing
		if (g_iMAEntid[iCid] == iEntid
				&& g_flMANextTime[iCid]>=flNextTime_ret)
		{
			//----DEBUG----
			//PrintToChatAll("\x03DT client \x01%i\x03; before shot made",iCid );

			continue;
		}

		//CHECK 3: AFTER ADJUSTED ATT IS MADE
		//------------------------------------
		//at this point, either a gun was swapped, or
		//the attack time needs to be adjusted
		//checks: stored gun id same as retrieved gun id,
		// and retrieved next attack time is after stored value
		//actions: adjusts next attack time
		if (g_iMAEntid[iCid] == iEntid && g_flMANextTime[iCid] < flNextTime_ret)
		{
			if (MFd == 1) 
			{
				
				g_iMAAttCount[iCid]++;
				if (g_iMAAttCount[iCid]>MF_countd)
				g_iMAAttCount[iCid]=1;
				if (g_iMAAttCount[iCid]==MF_countd)
				{
					flNextTime_calc = flGameTime + MF_timed ;

					//then we store the value
					g_flMANextTime[iCid] = flNextTime_calc;

					SetEntDataFloat(iEntid, g_iNextPAttO, flNextTime_calc, true);
					SetEntDataFloat(iEntid, g_iNextSAttO, flNextTime_calc, true);
					g_flMFsave[iCid] =flNextTime_calc;
					g_flMFlasttime[iCid] =flGameTime;
					PrintHintText(iCid,"Melee Fatigue");

					//----DEBUG----
					//PrintToChatAll("\x03-post, NextTime_calc \x01 %f\x03; new interval \x01%f",GetEntDataFloat(iEntid,g_iNextPAttO), GetEntDataFloat(iEntid,g_iNextPAttO)-flGameTime );

					continue;
				}
				else
				{
					//this is a calculation of when the next primary attack
					//will be after applying double tap values
					//flNextTime_calc = ( flNextTime_ret - flGameTime ) * g_flMA_attrate + flGameTime;
					
					if (melee_speed[iCid] <= 0.0)
					{
						flNextTime_calc = flGameTime + maspeedd ;
					}
					else
					{
						flNextTime_calc = flGameTime + melee_speed[iCid] ;
					}
					//then we store the value
					g_flMANextTime[iCid] = flNextTime_calc;

					//and finally adjust the value in the gun
					SetEntDataFloat(iEntid, g_iNextPAttO, flNextTime_calc, true);

					//----DEBUG----
					//PrintToChatAll("\x03-post, NextTime_calc \x01 %f\x03; new interval \x01%f",GetEntDataFloat(iEntid,g_iNextPAttO), GetEntDataFloat(iEntid,g_iNextPAttO)-flGameTime );

					continue;
				}
			}
			else
			{
				//----DEBUG----
				//PrintToChatAll("\x03DT after adjusted shot\n-pre, client \x01%i\x03; entid \x01%i\x03; enginetime\x01 %f\x03; NextTime_orig \x01 %f\x03; interval \x01%f",iCid,iEntid,flGameTime,flNextTime_ret, flNextTime_ret-flGameTime );

				//this is a calculation of when the next primary attack
				//will be after applying double tap values
				//flNextTime_calc = ( flNextTime_ret - flGameTime ) * g_flMA_attrate + flGameTime;
				if (melee_speed[iCid] <= 0.0)
				{
					flNextTime_calc = flGameTime + maspeedd ;
				}
				else
				{
					flNextTime_calc = flGameTime + melee_speed[iCid] ;
				}

				//then we store the value
				g_flMANextTime[iCid] = flNextTime_calc;

				//and finally adjust the value in the gun
				SetEntDataFloat(iEntid, g_iNextPAttO, flNextTime_calc, true);

				//----DEBUG----
				//PrintToChatAll("\x03-post, NextTime_calc \x01 %f\x03; new interval \x01%f",GetEntDataFloat(iEntid,g_iNextPAttO), GetEntDataFloat(iEntid,g_iNextPAttO)-flGameTime );

				continue;
			}
		}

		//CHECK 4: CHECK THE WEAPON
		//-------------------------
		//lastly, at this point we need to check if we are, in fact,
		//using a melee weapon =P we check if the current weapon is
		//the same one stored in memory; if it is, move on;
		//otherwise, check if it's a melee weapon - if it is,
		//store and continue; else, continue.
		//checks: if the active weapon is a melee weapon
		//actions: store the weapon's entid into either
		// the known-melee or known-non-melee variable

		//----DEBUG----
		//PrintToChatAll("\x03DT client \x01%i\x03; weapon switch inferred",iCid );

		//check if the weapon is a melee
		decl String:stName[32];
		GetEntityNetClass(iEntid,stName,32);
		if (StrEqual(stName,"CTerrorMeleeWeapon",false)==true)
		{
			//if yes, then store in known-melee var
			g_iMAEntid[iCid]=iEntid;
			g_flMANextTime[iCid]=flNextTime_ret;
			continue;
		}
		else
		{
			//if no, then store in known-non-melee var
			g_iMAEntid_notmelee[iCid]=iEntid;
			continue;
		}
	}
	return 0;
}


public ConVarChanged_cvar_ammo(Handle:convar, const String:oldValue[], const String:newValue[])
{
	ammod = GetConVarInt(cvar_ammo);
}
public ConVarChanged_cvar_ammolower(Handle:convar, const String:oldValue[], const String:newValue[])
{
	ammolowerd = GetConVarInt(cvar_ammolower);
}
public ConVarChanged_cvar_ammoupper(Handle:convar, const String:oldValue[], const String:newValue[])
{
	ammoupperd = GetConVarInt(cvar_ammoupper);
}
public ConVarChanged_cvar_notice(Handle:convar, const String:oldValue[], const String:newValue[])
{
	noticed = GetConVarInt(cvar_notice);
}
public ConVarChanged_cvar_lownotice(Handle:convar, const String:oldValue[], const String:newValue[])
{
	lownoticed = GetConVarInt(cvar_lownotice);
}
public ConVarChanged_cvar_pistol(Handle:convar, const String:oldValue[], const String:newValue[])
{
	pistold = GetConVarInt(cvar_pistol);
}
public ConVarChanged_cvar_escapeammo(Handle:convar, const String:oldValue[], const String:newValue[])
{
	escapeammod = GetConVarInt(cvar_escapeammo);
}
public ConVarChanged_cvar_killammo(Handle:convar, const String:oldValue[], const String:newValue[])
{
	killammod = GetConVarInt(cvar_killammo);
}
public ConVarChanged_cvar_IE(Handle:convar, const String:oldValue[], const String:newValue[])
{
	IEd = GetConVarInt(cvar_IE);
}
public ConVarChanged_cvar_MA(Handle:convar, const String:oldValue[], const String:newValue[])
{
	MAd = GetConVarInt(cvar_MA);
}
public ConVarChanged_cvar_maspeed(Handle:convar, const String:oldValue[], const String:newValue[])
{
	maspeedd = GetConVarFloat(cvar_maspeed);
}
public ConVarChanged_cvar_MF(Handle:convar, const String:oldValue[], const String:newValue[])
{
	MFd = GetConVarInt(cvar_MF);
}
public ConVarChanged_cvar_MF_count(Handle:convar, const String:oldValue[], const String:newValue[])
{
	MF_countd = GetConVarInt(cvar_MF_count);
}
public ConVarChanged_cvar_MF_time(Handle:convar, const String:oldValue[], const String:newValue[])
{
	MF_timed = GetConVarFloat(cvar_MF_time);
}

public ConVarChanged_cvar_lang(Handle:convar, const String:oldValue[], const String:newValue[])
{
	langd = GetConVarInt(cvar_lang);
}
public OnConfigsExecuted()
{
	ammod = GetConVarInt(cvar_ammo);
	ammolowerd = GetConVarInt(cvar_ammolower);
	ammoupperd = GetConVarInt(cvar_ammoupper);
	noticed = GetConVarInt(cvar_notice);
	lownoticed = GetConVarInt(cvar_lownotice);
	pistold = GetConVarInt(cvar_pistol);
	escapeammod = GetConVarInt(cvar_escapeammo);
	killammod = GetConVarInt(cvar_killammo);
	IEd = GetConVarInt(cvar_IE);
	MAd = GetConVarInt(cvar_MA);
	maspeedd = GetConVarFloat(cvar_maspeed);
	MFd = GetConVarInt(cvar_MF);
	MF_countd = GetConVarInt(cvar_MF_count);
	MF_timed = GetConVarFloat(cvar_MF_time);
	langd = GetConVarInt(cvar_lang);

}