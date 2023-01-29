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
*	12/05/2020 Version 1.8.6b – Fixed incorrect height speed initialization; fixed rare case, when a player could touch single zombie 2 times;
*							removed "st_autocb_const_speed" ConVar; added some additional debug message.
*							Update #8: Method of Auto Commonboost has changed. Now player can do auto-cb from idle zombie.
*							Vector building of SEQ_VEL_SHOVED_BACKWARD length is now depends only of player direction,
*							by cause such method nearest to the real cb. Also, returned m_nSequence checks before execute to strict boost control.
*							Speedrunners, Be Wise & Note: We still cannot release it as a stable tool and don't guarantee properly work for some cases.
*							This plugin is BETA, watch out in using in non-standard situations. We don't recommend use it in speedruns w/o tests.
*/

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PLUGIN_VER "1.8.6b"
#define MAXCLIENTS 32
#define SEQ_VEL_SHOVED_BACKWARD 154.481

new Handle:g_ConVar_CB;
new Handle:g_hOnAutoCB;
new bool:g_bIsCB_RootKey[MAXCLIENTS + 1];
new g_iTicks[MAXCLIENTS + 1];
new g_iEntity[MAXCLIENTS + 1];
new Float:g_fSpeed_Player[MAXCLIENTS + 1];
new Float:g_fSpeed_Entity[MAXCLIENTS + 1];
new Float:g_fAngles_Player[MAXCLIENTS + 1];
new Float:g_fAngles_Entity[MAXCLIENTS + 1];
new Float:g_fDifference[MAXCLIENTS + 1];
new Float:g_vecEntity[MAXCLIENTS + 1][3];
new Float:g_vecPlayer[MAXCLIENTS + 1][3];

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
		decl String:sEntNetClass[16];
		GetEntityNetClass(entity, sEntNetClass, sizeof(sEntNetClass));
		if (StrEqual(sEntNetClass, "Infected"))
		{
			new client = GetClientOfUserId(GetEventInt(event, "attacker"));
			if (!g_bIsCB_RootKey[client])
			{
				decl Float:vecVel[3], Float:vecAng[3];
				GetEntPropVector(entity, Prop_Data, "m_vecVelocity", vecVel);
				GetEntPropVector(entity, Prop_Send, "m_angRotation", vecAng);
				g_fSpeed_Entity[client] = GetVectorLength(vecVel);
				g_fAngles_Entity[client] = vecAng[1];
				g_iTicks[client] = GetGameTickCount();
				g_iEntity[client] = entity;
				g_vecEntity[client] = vecVel;
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
			if (buttons & IN_JUMP && (GetGameTickCount() - g_iTicks[client]) <= 3 && GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") == g_iEntity[client])
			{
				new iSeq = GetEntProp(g_iEntity[client], Prop_Data, "m_nSequence");
				if (iSeq >= 122 && iSeq <= 131)
				{
					decl Float:vecVel[3];
					GetEntPropVector(client, Prop_Data, "m_vecVelocity", vecVel);
					g_fSpeed_Player[client] = GetVectorLength(vecVel);
					if (g_fSpeed_Player[client] > 0)
					{
						decl Float:vecAng[3];
						GetVectorAngles(vecVel, vecAng);
						g_fAngles_Player[client] = DegToRad(vecAng[1]);
						g_fAngles_Entity[client] = DegToRad(g_fAngles_Entity[client]) + FLOAT_PI;
						if (g_fAngles_Entity[client] >= FLOAT_PI*2) g_fAngles_Entity[client] -= RoundToFloor(g_fAngles_Entity[client])/6*FLOAT_PI*2;
						float fDifference = g_fAngles_Entity[client] - g_fAngles_Player[client];
						if (fDifference < 0) fDifference *= -1;
						if (fDifference > FLOAT_PI) fDifference = FLOAT_PI*2 - fDifference;
						if (fDifference < FLOAT_PI/4)
						{
							g_iTicks[client] = GetGameTickCount() - g_iTicks[client];
							g_fDifference[client] = fDifference;
							g_bIsCB_RootKey[client] = true;
							g_vecPlayer[client] = vecVel;
							vecVel[0] = Cosine(g_fAngles_Player[client])*SEQ_VEL_SHOVED_BACKWARD;
							vecVel[1] = Sine(g_fAngles_Player[client])*SEQ_VEL_SHOVED_BACKWARD;
							vecVel[2] = 0.0;
							AddVectors(g_vecPlayer[client], vecVel, g_vecPlayer[client]);
							SDKHooks_TakeDamage(g_iEntity[client], client, client, 50.0, DMG_GENERIC);
						}
					}
				}
			}
		}
		else
		{
			if (IsPlayerAlive(client) && !GetEntProp(client, Prop_Send, "m_isIncapacitated"))
			{
				decl Float:vecVel[3], Float:vecAng[3], String:sEntName[128]; sEntName[0] = 0;
				if (IsValidEntity(g_iEntity[client])) GetEntPropString(g_iEntity[client], Prop_Data, "m_iName", sEntName, sizeof(sEntName));
				GetEntPropVector(client, Prop_Data, "m_vecVelocity", vecVel);
				NegateVector(g_vecEntity[client]);
				AddVectors(g_vecEntity[client], g_vecPlayer[client], g_vecPlayer[client]);
				vecVel[0] = g_vecPlayer[client][0];
				vecVel[1] = g_vecPlayer[client][1];
				TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vecVel);
				GetVectorAngles(vecVel, vecAng);
				
				PrintToConsole(client, "[SM] Completed AutoCB successfully.\n------------------- Debug Info -------------------");
				PrintToConsole(client, "Velocity CB  : %.03f\nSpeedEntity  : %.03f", SquareRoot(Pow(vecVel[0], 2.0) + Pow(vecVel[1], 2.0)), g_fSpeed_Entity[client]);
				PrintToConsole(client, "SpeedPlayer  : %.03f\nSpeedSeq     : %.03f", g_fSpeed_Player[client], SEQ_VEL_SHOVED_BACKWARD);
				PrintToConsole(client, "AngEntity    : %.03f (%.03f)", g_fAngles_Entity[client], RadToDeg(g_fAngles_Entity[client]));
				PrintToConsole(client, "AngPlayer    : %.03f (%.03f)", g_fAngles_Player[client], RadToDeg(g_fAngles_Player[client]));
				PrintToConsole(client, "Idx          : %d\nDirection    : %.03f (%.03f)", g_iEntity[client], DegToRad(vecAng[1]), vecAng[1]);
				PrintToConsole(client, "Difference   : %.03f (%.03f)", g_fDifference[client], RadToDeg(g_fDifference[client]));
				PrintToConsole(client, "Ticks        : %d\nName         : %s", g_iTicks[client], sEntName);
				PrintToConsole(client, "m_vecVelocity: Vector(%.03f, %.03f, %.03f)", vecVel[0], vecVel[1], vecVel[2]);
				PrintToConsole(client, "Length       : %.03f\nVersion      : %s\n---------------------------------------------------", GetVectorLength(vecVel), PLUGIN_VER);
				
				Call_StartForward(g_hOnAutoCB);
				Call_PushCell(client);
				Call_PushString(sEntName);
				Call_Finish();
				Format(sEntName, sizeof(sEntName), "if (\"OnAutoCB\" in getroottable()) OnAutoCB(self, \"%s\")", sEntName);
				SetVariantString(sEntName);
				AcceptEntityInput(client, "RunScriptCode");
			}
			g_bIsCB_RootKey[client] = false;
		}
	}
	return Plugin_Continue;
}