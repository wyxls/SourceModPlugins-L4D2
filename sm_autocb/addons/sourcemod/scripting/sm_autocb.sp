//SourcePawn

/*			Changelog
*	15/04/2017 Version 1.0 – Created.
*	01/11/2017 Version 1.1 – Beta released; changed cb method: works relative player move direction with constant speed.
*	16/11/2017 Version 1.3 – ??
*	11/02/2018 Version 1.4.1 – ??
*	15/07/2018 Version 1.5.2 – Defined constant with max. possible velocity at ACT_TERROR_SHOVED_BACKWARD sequence
*							(Sequence: (122) Shoved_Backward_01). Now auto-commonboost will be sensitive to player and zombie velocity.
*	24/07/2018 Version 1.6.2 – Added JUMP_HEIGHT and JUMP_HEIGHT_DUCKING defines; added SDKHooks_TakeDamage() function;
*							removed checks via m_nSequence before auto-commonboost for ease of use.
*	09/11/2018 Version 1.6.3 – Some changes in syntax.
*	10/08/2019 Version 1.7.3 – Changed cb method: player gets boost in the direction between his move vector and zombie's as well. Difference of
*							move angles must be no more 1/4PI for success. Added ConVar "st_autocb_const_speed" to specify constant speed
*							for auto-commonboost. Created global forward "OnAutoCB" to hook event after auto-cb is done; also the same
*							function being called from VScript if exists.
*	11/10/2019 Version 1.7.4 – Fixed incorrect boost initializing. Prohibited to receive data on game event during commonboost: player was
*							able to shove the other infecteds in the same tick, where he's already touching one, thus plugin could update to wrong
*							move angle for the first infected. Added OnClientDisconnect() to reset commonboost if started. Changed debug
*							text output in console after CB is completed.
*	27/01/2020 Version 1.7.5 – Added function parameter for OnAutoCB forward to send zombie targetname.
*/

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PLUGIN_VER "1.7.5"
#define MAXCLIENTS 32
#define SEQ_VEL_SHOVED_BACKWARD 154.481
#define JUMP_HEIGHT_DUCKING 275.326
#define JUMP_HEIGHT 223.133

new Handle:g_ConVar_CB;
new Handle:g_ConVar_CB_ConstSpeed;
new Handle:g_hOnAutoCB;
new bool:g_bIsCB_RootKey[MAXCLIENTS + 1];
new g_iTicks[MAXCLIENTS + 1];
new g_iEntity[MAXCLIENTS + 1];
new Float:g_fSpeed_Player[MAXCLIENTS + 1];
new Float:g_fSpeed_Entity[MAXCLIENTS + 1];
new Float:g_fAngles_Player[MAXCLIENTS + 1];
new Float:g_fAngles_Entity[MAXCLIENTS + 1];
new Float:g_fJumpHeight[MAXCLIENTS + 1];
new Float:g_fDifference[MAXCLIENTS + 1];

public Plugin:myinfo =
{
	name = "Auto Commonboost",
	author = "noa1mbot",
	description = "Allows to do commonboost easier.",
	version = PLUGIN_VER,
	url = "http://steamcommunity.com/sharedfiles/filedetails/?id=510955402"
}

//============================================================
//============================================================

public OnPluginStart()
{
	g_ConVar_CB = CreateConVar("st_autocb", "1", "Activate auto-commonboost on the server.", FCVAR_NOTIFY);
	g_ConVar_CB_ConstSpeed = CreateConVar("st_autocb_const_speed", "0.0", "Specify constant speed for auto-commonboost.", FCVAR_NOTIFY, true, 0.0, true, 3500.0);
	HookEvent("entity_shoved", Event_EntityShoved);
	g_hOnAutoCB = CreateGlobalForward("OnAutoCB", ET_Ignore, Param_Cell, Param_String);
}

public OnClientDisconnect(int client)
{
	if (g_bIsCB_RootKey[client])
	{
		g_bIsCB_RootKey[client] = false;
	}
}

public Event_EntityShoved(Event event, const char[] name, bool dontBroadcast)
{
	if (GetConVarBool(g_ConVar_CB))
	{
		new entity = GetEventInt(event, "entityid");
		decl String:sEntNetClass[64];
		GetEntityNetClass(entity, sEntNetClass, sizeof(sEntNetClass));
		if (StrEqual(sEntNetClass, "Infected"))
		{
			new iSeq = GetEntProp(entity, Prop_Data, "m_nSequence");
			if (iSeq >= 85 && iSeq <= 91)
			{
				new client = GetClientOfUserId(GetEventInt(event, "attacker"));
				if (!g_bIsCB_RootKey[client])
				{
					decl Float:vecVel[3], Float:vecAng[3];
					GetEntPropVector(entity, Prop_Data, "m_vecVelocity", vecVel);
					GetVectorAngles(vecVel, vecAng);
					g_fAngles_Entity[client] = DegToRad(vecAng[1]) + FLOAT_PI;
					g_fSpeed_Entity[client] = GetVectorLength(vecVel);
					g_iTicks[client] = GetGameTickCount();
					g_iEntity[client] = entity;
				}
			}
		}
	}
}

public Action:OnPlayerRunCmd(int client, int &buttons)
{
	if (GetConVarBool(g_ConVar_CB))
	{
		if (!g_bIsCB_RootKey[client])
		{
			if (buttons & IN_JUMP)
			{
				if ((GetGameTickCount() - g_iTicks[client]) <= 3)
				{
					if (GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") == g_iEntity[client])
					{
						decl Float:vecVel[3], Float:vecAng[3];
						GetEntPropVector(client, Prop_Data, "m_vecVelocity", vecVel);
						GetVectorAngles(vecVel, vecAng);
						g_fAngles_Player[client] = DegToRad(vecAng[1]);
						g_fSpeed_Player[client] = GetVectorLength(vecVel);
						if (g_fAngles_Entity[client] >= FLOAT_PI*2) g_fAngles_Entity[client] -= RoundToFloor(g_fAngles_Entity[client])/6*FLOAT_PI*2;
						if (g_fSpeed_Player[client] == 0) g_fAngles_Player[client] = g_fAngles_Entity[client];
						g_fDifference[client] = g_fAngles_Entity[client] - g_fAngles_Player[client];
						if (g_fDifference[client] < 0) g_fDifference[client] *= -1;
						if (g_fDifference[client] > FLOAT_PI) g_fDifference[client] = FLOAT_PI*2 - g_fDifference[client];
						if (g_fDifference[client] < FLOAT_PI/4)
						{
							g_fJumpHeight[client] = GetEntityFlags(client) & FL_DUCKING ? JUMP_HEIGHT_DUCKING : JUMP_HEIGHT;
							SDKHooks_TakeDamage(g_iEntity[client], client, client, 50.0, DMG_GENERIC);
							g_bIsCB_RootKey[client] = true;
						}
					}
				}
			}
		}
		else
		{
			if (IsPlayerAlive(client) && !GetEntProp(client, Prop_Send, "m_isIncapacitated"))
			{
				decl Float:vecVel[3];
				new Float:fVelocity = GetConVarFloat(g_ConVar_CB_ConstSpeed);
				new Float:fRad = (g_fAngles_Entity[client] + g_fAngles_Player[client])/2;
				if ((g_fAngles_Entity[client] - g_fAngles_Player[client]) > FLOAT_PI || (g_fAngles_Player[client] - g_fAngles_Entity[client]) > FLOAT_PI) fRad -= FLOAT_PI;
				if (fVelocity == 0) fVelocity = g_fSpeed_Entity[client] + g_fSpeed_Player[client] + SEQ_VEL_SHOVED_BACKWARD;
				vecVel[0] = Cosine(fRad)*fVelocity;
				vecVel[1] = Sine(fRad)*fVelocity;
				vecVel[2] = g_fJumpHeight[client];
				TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vecVel);
				
				char sEntName[128];
				if (IsValidEntity(g_iEntity[client])) GetEntPropString(g_iEntity[client], Prop_Data, "m_iName", sEntName, sizeof(sEntName));
				Call_StartForward(g_hOnAutoCB);
				Call_PushCell(client);
				Call_PushString(sEntName);
				Call_Finish();
				Format(sEntName, sizeof(sEntName), "if (\"OnAutoCB\" in getroottable()) OnAutoCB(self, \"%s\")", sEntName);
				SetVariantString(sEntName);
				AcceptEntityInput(client, "RunScriptCode");
				PrintToConsole(client, "[SM] Completed AutoCB successfully.\n---------- Debug Info ----------");
				PrintToConsole(client, "Velocity CB : %.03f", fVelocity);
				PrintToConsole(client, "Entity speed: %.03f", g_fSpeed_Entity[client]);
				PrintToConsole(client, "Player speed: %.03f", g_fSpeed_Player[client]);
				PrintToConsole(client, "Entity index: %d", g_iEntity[client]);
				PrintToConsole(client, "Entity angle: %.03f (%.03f)", g_fAngles_Entity[client], RadToDeg(g_fAngles_Entity[client]));
				PrintToConsole(client, "Player angle: %.03f (%.03f)", g_fAngles_Player[client], RadToDeg(g_fAngles_Player[client]));
				PrintToConsole(client, "Direction   : %.03f (%.03f)", fRad, RadToDeg(fRad));
				PrintToConsole(client, "Difference  : %.03f (%.03f)", g_fDifference[client], RadToDeg(g_fDifference[client]));
				PrintToConsole(client, "--------------------------------");
			}
			g_bIsCB_RootKey[client] = false;
		}
	}
	return Plugin_Continue;
}