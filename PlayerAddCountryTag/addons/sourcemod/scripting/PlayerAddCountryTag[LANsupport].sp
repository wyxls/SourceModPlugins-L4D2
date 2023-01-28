#include <sourcemod>
#include <sdktools>
#include <geoip>
#include <regex>
#include <colors>

#pragma semicolon 1
#pragma newdecls required

#define CVAR_FLAGS FCVAR_SPONLY|FCVAR_NOTIFY
#define VERSION "2.5.0-1h"

UserMsg g_SayText2;
char OriginalName[MAXPLAYERS+1][MAX_NAME_LENGTH];

ConVar PlayerJoinMessage;
ConVar PlayerJoinMessageLayout;
ConVar ShowIsAdminOnMessages;
ConVar ShowIsAdminInScore;
ConVar NameLayout;
ConVar AdminLayout;
ConVar PACTLIST_Layout;
ConVar LANcountry;
ConVar ChangeName;
ConVar PluginVersionCVAR;

Handle ip_regex = INVALID_HANDLE;

public Plugin myinfo =
{
	name = "PlayerAddCountryTag",
	author = "n3wton",
	description = "Add country tag to users name",
	version = VERSION
};

public void OnPluginStart()
{
	PlayerJoinMessage = CreateConVar("PACT_Player_Join_Message", "1", "Show a message on player join ('PLAYER' from 'LOCATION' has joined)", CVAR_FLAGS);
	PlayerJoinMessageLayout = CreateConVar("PACT_Player_Join_Message_Layout", "{NAME} from {LOC} has joined.", "Format of the welcome message, {NAME} = player name, {LOC} = country", CVAR_FLAGS);
	ShowIsAdminOnMessages = CreateConVar("PACT_Show_Admin_Messages", "1", "Highlight admins in yellow in chat messages", CVAR_FLAGS);
	ShowIsAdminInScore = CreateConVar("PACT_Show_Admin_Score", "1", "Put AdminTag infront of all admins in score", CVAR_FLAGS);
	NameLayout = CreateConVar("PACT_Name_Layout", "{NAME} [{TAG}]", "Layout of how the clients name should look", CVAR_FLAGS);
	AdminLayout = CreateConVar("PACT_Admin_Layout", "(A) {NAME}", "Layout of how and what the admin tag should look like, (Note: {NAME} equates to the string genorated from PACT_Name_Layout", CVAR_FLAGS );
	PACTLIST_Layout = CreateConVar("PACT_List_Layout", "{NAME} is from {LOC}", "Layout of how !pactlist should be displayed", CVAR_FLAGS);
	LANcountry = CreateConVar("PACT_LANcountry", "--", "Country code {UK, US, CA, etc.} for LAN computers. Two characters max.", CVAR_FLAGS);
	ChangeName = CreateConVar("PACT_ChangeName", "1", "Broadcast a chat message when a player changes his name.", CVAR_FLAGS);
	PluginVersionCVAR = CreateConVar("PACT_Version", VERSION, "Version of the Player Add Country Tag (PACT) plugin.", CVAR_FLAGS);
	AutoExecConfig(true, "PlayerAddCountryTag");

	g_SayText2 = GetUserMessageId("SayText2");
	HookUserMessage(g_SayText2, UserMessageHook, true);
	HookEvent("player_changename", Event_PlayerChangename, EventHookMode_Pre);

	RegConsoleCmd("sm_pactlist", listPlayersAndCountry, "List all players names and countries");

	ip_regex = CompileRegex("^(192|172|127|10)\\.");
}

public void OnClientPostAdminCheck(int client)
{
	if( client != 0 )
	{
		if( !IsFakeClient( client ) )
		{
			char IP[16];
			char Country[100];
			GetClientIP( client, IP, 16 );
			if( GetConVarBool(PlayerJoinMessage) )
			{
				if( GeoipCountry( IP, Country, 100 ) )
				{
					char JoinMessage[256];
					char Name[MAX_NAME_LENGTH];
					GetClientName( client, Name, MAX_NAME_LENGTH );

					if( StrContains( Country, "United", false ) != -1 || StrContains( Country, "Republic", false ) != -1 || StrContains( Country, "Netherlands", false ) != -1 || StrContains( Country, "Philippines", false ) != -1 )
					{
						Format( Country, 100, "The %s", Country );
					}

					GetConVarString(PlayerJoinMessageLayout, JoinMessage, 256);
					if (StrContains(JoinMessage, "{NAME}", false) != -1) ReplaceString(JoinMessage, sizeof(JoinMessage), "{NAME}", Name);
					if (StrContains(JoinMessage, "{LOC}", false) != -1) ReplaceString(JoinMessage, sizeof(JoinMessage), "{LOC}", Country);

					//if( GetUserAdmin(client) != INVALID_ADMIN_ID && GetConVarBool(ShowIsAdminOnMessages) )
					if( GetUserFlagBits(client) > 1 && GetConVarBool(ShowIsAdminOnMessages) ) //SM 1.11 fix by Foundhound
					{
						PrintToChatAll("\x04%s", JoinMessage);
					}
					else
					{
						PrintToChatAll(JoinMessage);
					}
				}
				else
				{
					//if( GetUserAdmin(client) != INVALID_ADMIN_ID && GetConVarBool(ShowIsAdminOnMessages) )
					if( GetUserFlagBits(client) > 1 && GetConVarBool(ShowIsAdminOnMessages) ) //SM 1.11 fix by Foundhound
					{
						PrintToChatAll( "\x04%N has joined", client );
					}
					else
					{
						PrintToChatAll( "%N has joined", client );
					}
				}
			}

			GetClientName( client, OriginalName[client], MAX_NAME_LENGTH );
			char NameWithTag[MAX_NAME_LENGTH];
			getPlayerNameWithTag( client, NameWithTag, MAX_NAME_LENGTH );
			SetClientInfo( client, "name", NameWithTag );

			//If Admin and Config Wrong Show Error Message
			//if( GetUserAdmin( client ) != INVALID_ADMIN_ID && GetConVarFloat(PluginVersionCVAR) != StringToFloat(VERSION) )
			if( GetUserFlagBits(client) > 1 && GetConVarFloat(PluginVersionCVAR) != StringToFloat(VERSION) ) //SM 1.11 fix by Foundhound
			{
				PrintToChat( client, "\x03PACT ERROR!" );
				PrintToChat( client, "\x03You are using plugin version %s", VERSION );
				PrintToChat( client, "\x03Where as your .cfg is using version %f.", GetConVarFloat(PluginVersionCVAR) );
				PrintToChat( client, "\x03Please delete your .cfg file from cfg/sourcemod and restart the server" );
			}
		}
	}
}

public Action listPlayersAndCountry(int client, int args)
{
	if( client != 0 )
	{
		if( !IsFakeClient( client ) )
		{
			for( int i = 1; i <= MaxClients; i++)
			{
				if (IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i))
				{
					char Country[100];
					char IP[16];
					char Layout[256];
					GetConVarString( PACTLIST_Layout, Layout, 256 );
					GetClientIP(i, IP, 16);
					if( !GeoipCountry(IP, Country, 100) )
					{
						Format( Country, 100, "an Unknown Location" );
					}
					if( StrContains( Country, "United", false ) != -1 || StrContains( Country, "Republic", false ) != -1 || StrContains( Country, "Netherlands", false ) != -1 || StrContains( Country, "Philippines", false ) != -1 )
					{
						Format( Country, 100, "The %s", Country );
					}
					if( StrContains( Layout, "{NAME}", false ) != -1 )
					{
						ReplaceString( Layout, 256, "{NAME}", OriginalName[i], false );
					}
					if( StrContains( Layout, "{LOC}", false ) != -1 )
					{
						ReplaceString( Layout, 256, "{LOC}", Country, false );
					}
					//if( GetUserAdmin(i) != INVALID_ADMIN_ID && GetConVarBool(ShowIsAdminOnMessages) )
					if( GetUserFlagBits(i) > 1 && GetConVarBool(ShowIsAdminOnMessages) ) //SM 1.11 fix by Foundhound
					{
						PrintToChat( client, "\x04%s", Layout );
					}
					else
					{
						PrintToChat( client, "%s", Layout );
					}
				}
			}
		}
	}
}

void getPlayerTag(int client, char[] Tag, int size)
{
	char IP[16];
	char Code[3];
	char LANcode[3];
	Format( Tag, size, "%s", "--" );
	GetClientIP(client, IP, 16);
	GetConVarString(LANcountry, LANcode, 3);

	if( GeoipCode2(IP, Code) )
	{
		Format( Tag, size, "%2s", Code );
	}

	if(MatchRegex(ip_regex, IP) > 0 )
	{
		Format( Tag, size, LANcode, Code );
	}
}

void getPlayerNameWithTag(int client, char[] NameWithTag, int size)
{
	char Tag[5];
	char Name[MAX_NAME_LENGTH];
	char Layout[256];

	GetClientName( client, Name, MAX_NAME_LENGTH );
	getPlayerTag( client, Tag, 5 );

	GetConVarString( NameLayout, Layout, 256 );
	if( StrContains( Layout, "{NAME}", false ) != -1 )
	{
		ReplaceString(Layout, sizeof(Layout), "{NAME}", Name);
	}
	if( StrContains( Layout, "{TAG}", false ) != -1 )
	{
		ReplaceString(Layout, sizeof(Layout), "{TAG}", Tag);
	}
	Format( NameWithTag, size, "%s", Layout );
	//if( GetUserAdmin( client ) != INVALID_ADMIN_ID && GetConVarBool(ShowIsAdminInScore) )
	if( GetUserFlagBits(client) > 1 && GetConVarBool(ShowIsAdminInScore) ) //SM 1.11 fix by Foundhound
	{ //if they are an admin
		char AdmLayout[256];
		GetConVarString( AdminLayout, AdmLayout, 256 );
		if( StrContains( AdmLayout, "{NAME}", false ) != -1 )
		{
			ReplaceString( AdmLayout, sizeof(AdmLayout), "{NAME}", NameWithTag );
		}
		Format(  NameWithTag, size, "%s", AdmLayout );
	}
}

public Action UserMessageHook(UserMsg msg_id, Handle bf, const int[] players, int playersNum, bool reliable, bool init)
{
	char message[256];
	BfReadString(bf, message, sizeof(message));
	BfReadString(bf, message, sizeof(message));
	if (StrContains( message, "Name_Change", false) != -1)
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action Event_PlayerChangename(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId( GetEventInt(event, "userid") );
	if( client != 0 )
	{
		if( !IsFakeClient( client ) )
		{
			char NewName[MAX_NAME_LENGTH];
			char Tag[5];
			char Layout[256];

			GetEventString( event, "newname", NewName, MAX_NAME_LENGTH );
			getPlayerTag( client, Tag, 5 );
			if( StrContains( NewName, Tag, false ) == -1 )
			{
				if(GetConVarBool(ChangeName))
					PrintToChatAll("\x05%N \x01changed name to \x05%s", client, NewName);

				GetConVarString( NameLayout, Layout, 256 );
				if( StrContains( Layout, "{NAME}", false ) != -1 )
				{
					ReplaceString(Layout, sizeof(Layout), "{NAME}", NewName);
				}
				if( StrContains( Layout, "{TAG}", false ) != -1 )
				{
					ReplaceString(Layout, sizeof(Layout), "{TAG}", Tag);
				}
				Format( NewName, MAX_NAME_LENGTH, "%s", Layout);
			}

			//if( GetUserAdmin( client ) != INVALID_ADMIN_ID )
			if( GetUserFlagBits(client) > 1 ) //SM 1.11 fix by Foundhound
			{
				char AdmLayout[256];
				GetConVarString( AdminLayout, AdmLayout, 256 );
				ReplaceString( AdmLayout, 256, "{NAME}", "" );
				if( StrContains( NewName, AdmLayout, false ) == -1 )
				{
					GetConVarString( AdminLayout, AdmLayout, 256 );
					if( StrContains( AdmLayout, "{NAME}", false ) != -1 )
					{
						ReplaceString( AdmLayout, sizeof(AdmLayout), "{NAME}", NewName );
					}
					Format(  NewName, MAX_NAME_LENGTH, "%s", AdmLayout );
				}
			}

			SetClientInfo( client, "name", NewName );
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}