#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#pragma semicolon 1

// ====================================================================================================
// Plugin Info - define
// ====================================================================================================
#define PLUGIN_NAME                   "L4D2 Chinese Server Name"
#define PLUGIN_AUTHOR                 "Zakikun"
#define PLUGIN_DESCRIPTION            "Change Server Name (support multiple servers and unicode characters)."
#define PLUGIN_VERSION                "1.0"
#define PLUGIN_URL                    ""

// ====================================================================================================
// Plugin Info
// ====================================================================================================

public Plugin myinfo = 
{
        name            = PLUGIN_NAME,
        author          = PLUGIN_AUTHOR,
        description     = PLUGIN_DESCRIPTION,
        version         = PLUGIN_VERSION,
        url             = PLUGIN_URL
}

// ====================================================================================================
// Defines
// ====================================================================================================
#define KEYVALUE_FILENAME       "hostname"
#define KEYVALUE_ROOTNAME       "Settings"
#define KEYVALUE_HOSTNAME       "HostName"

// ====================================================================================================
// Global Cvar Variables
// ====================================================================================================
char g_sDataPath[PLATFORM_MAX_PATH];
char g_sHostName[256];
char g_sNewHostName[256];

public void OnPluginStart()
{
        HookEvent("round_start", ChangeHostName);
        HookEvent("round_end", ChangeHostName);
        RegAdminCmd("hostname_debug", Command_Debug, ADMFLAG_CHEATS);
}

public void OnMapStart()
{
        BuildPath(Path_SM, g_sDataPath, sizeof(g_sDataPath),"configs/%s.txt", KEYVALUE_FILENAME);
        GetConVarString(FindConVar("hostname"), g_sHostName, sizeof(g_sHostName));
        PrintToChatAll(g_sHostName);

        if( !FileExists(g_sDataPath) )
        return;

        KeyValues kv = new KeyValues(KEYVALUE_ROOTNAME);
        kv.ImportFromFile(g_sDataPath);
        kv.JumpToKey(KEYVALUE_HOSTNAME);

        char num[4];
        char buffer[256];
        for (new i = 1; i <= 99; i++)
        {
                if( i <= 9)
                {
                        Format(num, sizeof(num), "0%i", i);
                }
                else
                {
                        Format(num, sizeof(num), "%i", i);
                }

                Format(buffer, sizeof(buffer), "{%s}#%s", KEYVALUE_HOSTNAME, num);
                if(strcmp(g_sHostName, buffer, true) == 0)
                {
                        kv.GetString(buffer, g_sNewHostName, sizeof(g_sNewHostName));
                        SetConVarString(FindConVar("hostname"), g_sNewHostName);
                }
        }

        delete kv;
}

public void ChangeHostName(Handle:event, const String:name[], bool:dontBroadcast)
{
        BuildPath(Path_SM, g_sDataPath, sizeof(g_sDataPath),"configs/%s.txt", KEYVALUE_FILENAME);
        GetConVarString(FindConVar("hostname"), g_sHostName, sizeof(g_sHostName));
        PrintToChatAll(g_sHostName);

        if( !FileExists(g_sDataPath) )
        return;

        KeyValues kv = new KeyValues(KEYVALUE_ROOTNAME);
        kv.ImportFromFile(g_sDataPath);
        kv.JumpToKey(KEYVALUE_HOSTNAME);

        char num[4];
        char buffer[256];
        for (new i = 1; i <= 99; i++)
        {
                if( i <= 9)
                {
                        Format(num, sizeof(num), "0%i", i);
                }
                else
                {
                        Format(num, sizeof(num), "%i", i);
                }

                Format(buffer, sizeof(buffer), "{%s}#%s", KEYVALUE_HOSTNAME, num);
                if(strcmp(g_sHostName, buffer, true) == 0)
                {
                        kv.GetString(buffer, g_sNewHostName, sizeof(g_sNewHostName));
                        SetConVarString(FindConVar("hostname"), g_sNewHostName);
                }
        }

        delete kv;
}

/* Debug Command */
public Action Command_Debug(int client, int args) 
{
        char buffer[256];
        char num[4];
        BuildPath(Path_SM, g_sDataPath, sizeof(g_sDataPath),"configs/%s.txt", KEYVALUE_FILENAME);
        GetConVarString(FindConVar("hostname"), g_sHostName, sizeof(g_sHostName));
        PrintToChat(client, "g_sHostName : %s", g_sHostName);

        if( !FileExists(g_sDataPath) )
        return Plugin_Handled;

        KeyValues kv = new KeyValues(KEYVALUE_ROOTNAME);
        kv.ImportFromFile(g_sDataPath);
        kv.JumpToKey(KEYVALUE_HOSTNAME);

        for (new i = 1; i <= 99; i++)
        {
                if( i <= 9)
                {
                        Format(num, sizeof(num), "0%i", i);
                }
                else
                {
                        Format(num, sizeof(num), "%i", i);
                }

                Format(buffer, sizeof(buffer), "{%s}#%s", KEYVALUE_HOSTNAME, num);
                
                if(strcmp(g_sHostName, buffer, true) == 0)
                {
                        kv.GetString(buffer, g_sNewHostName, sizeof(g_sNewHostName));
                        SetConVarString(FindConVar("hostname"), g_sNewHostName);
                        PrintToChat(client, "g_sNewHostName : %s", g_sNewHostName);
                }
        }

        delete kv;

	return Plugin_Handled;
}