/******************************************************
* 			L4D2: Satellite Cannon v1.4
*					Author: ztar
*					Modifier: Zakikun
* 			Web: http://ztar.blog7.fc2.com/
*******************************************************/
#include <sourcemod>
#include <sdktools>
#define PLUGIN_VERSION "1.3"

#define MODE_JUDGEMENT	1
#define MODE_BLIZZARD	2
#define MODE_INFERNO	3
#define MODE_SLEEP		-1

#define OFF				0
#define ON				1
#define NORMAL			0
#define VARTICAL		1
#define SURVIVOR		2
#define INFECTED		3
#define MOLOTOV 		0
#define EXPLODE 		1

/* Message */
#define MESSAGE_EMPTY			"ENERGY IS RUNNING OUT"
#define MESSAGE_SHIFT_JUDGEMENT	"MODE SHIFT: JUDGEMENT"
#define MESSAGE_SHIFT_BLIZZARD	"MODE SHIFT: BLIZZARD"
#define MESSAGE_SHIFT_INFERNO	"MODE SHIFT: INFERNO"
#define MESSAGE_SHIFT_SLEEP		"MODE SHIFT: SLEEP"

/* Sound */
#define SOUND_NEGATIVE	"npc/soldier1/misc18.wav"
#define SOUND_SHOOT01	"npc/soldier1/misc17.wav"
#define SOUND_SHOOT02	"npc/soldier1/misc19.wav"
#define SOUND_SHOOT03	"npc/soldier1/misc20.wav"
#define SOUND_SHOOT04	"npc/soldier1/misc21.wav"
#define SOUND_SHOOT05	"npc/soldier1/misc22.wav"
#define SOUND_SHOOT06	"npc/soldier1/misc23.wav"
#define SOUND_SHOOT07	"npc/soldier1/misc08.wav"
#define SOUND_SHOOT08	"npc/soldier1/misc02.wav"
#define SOUND_SHOOT09	"npc/soldier1/misc07.wav"
#define SOUND_TRACING	"items/suitchargeok1.wav"
#define SOUND_IMPACT01	"animation/van_inside_hit_wall.wav"
#define SOUND_IMPACT02	"ambient/explosions/explode_3.wav"
#define SOUND_IMPACT03	"ambient/atmosphere/firewerks_burst_01.wav"
#define SOUND_FREEZE	"physics/glass/glass_pottery_break3.wav"
#define SOUND_DEFROST	"physics/glass/glass_sheet_break1.wav"

/* Model */
#define ENTITY_GASCAN	"models/props_junk/gascan001a.mdl"
#define ENTITY_PROPANE	"models/props_junk/propanecanister001a.mdl"

/* Sprite */
#define SPRITE_BEAM		"materials/sprites/laserbeam.vmt"
#define SPRITE_HALO		"materials/sprites/halo01.vmt"
#define SPRITE_GLOW		"materials/sprites/glow01.vmt"

/* Particle */
#define PARTICLE_FIRE01	"molotov_explosion"
#define PARTICLE_FIRE02	"molotov_explosion_child_burst"

/* Cvars */
new Handle:sm_satellite_enable			= INVALID_HANDLE;
new Handle:sm_satellite_damage_01		= INVALID_HANDLE;
new Handle:sm_satellite_freeze_02		= INVALID_HANDLE;
new Handle:sm_satellite_damage_03		= INVALID_HANDLE;
new Handle:sm_satellite_burst_delay		= INVALID_HANDLE;
new Handle:sm_satellite_force			= INVALID_HANDLE;
new Handle:sm_satellite_radius_01		= INVALID_HANDLE;
new Handle:sm_satellite_radius_02		= INVALID_HANDLE;
new Handle:sm_satellite_radius_03		= INVALID_HANDLE;
new Handle:sm_satellite_limit_01		= INVALID_HANDLE;
new Handle:sm_satellite_limit_02		= INVALID_HANDLE;
new Handle:sm_satellite_limit_03		= INVALID_HANDLE;
new Handle:sm_satellite_height			= INVALID_HANDLE;
new Handle:sm_satellite_adminonly		= INVALID_HANDLE;
new Handle:sm_satellite_adminunlimit	= INVALID_HANDLE;

/* Grobal */
new m_iClip1;
new hActiveWeapon;
new g_BeamSprite;
new g_HaloSprite;
new g_GlowSprite;
new tEntity;

new operation[MAXPLAYERS+1];
new ticket[MAXPLAYERS+1];
new raycount[MAXPLAYERS+1];
new freeze[MAXPLAYERS+1];
new energy[MAXPLAYERS+1][4];
new Float:trsPos[MAXPLAYERS+1][3];

public Plugin:myinfo = 
{
	name = "[L4D2] Satellite Cannon",
	author = "ztar (modify by Zakikun)",
	description = "Three kind of vertical laser launches by shooting magnum. Switch mode by pushing zoom key",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=131504"
}

/******************************************************
*	When plugin started
*******************************************************/
public OnPluginStart()
{
	sm_satellite_enable			= CreateConVar("sm_satellite_enable","1","0:OFF 1:ON", FCVAR_NOTIFY);
	sm_satellite_damage_01		= CreateConVar("sm_satellite_damage_01","300.0", "Damage of Satellite cannon (Mode:JUDGEMENT)", FCVAR_NOTIFY);
	sm_satellite_freeze_02		= CreateConVar("sm_satellite_freeze_02","5.0", "Freeze time of Satellite cannon (Mode:BLIZZARD)", FCVAR_NOTIFY);
	sm_satellite_damage_03		= CreateConVar("sm_satellite_damage_03","420.0", "Damage of Satellite cannon (Mode:INFERNO)", FCVAR_NOTIFY);
	sm_satellite_burst_delay	= CreateConVar("sm_satellite_burst_delay","1.0", "Launching delay of Satellite cannon", FCVAR_NOTIFY);
	sm_satellite_force			= CreateConVar("sm_satellite_force","600.0", "Push force of Satellite cannon", FCVAR_NOTIFY);
	sm_satellite_radius_01		= CreateConVar("sm_satellite_radius_01","300.0", "Radius of Satellite cannon (Mode:JUDGEMENT)", FCVAR_NOTIFY);
	sm_satellite_radius_02		= CreateConVar("sm_satellite_radius_02","230.0", "Radius of Satellite cannon (Mode:BLIZZARD)", FCVAR_NOTIFY);
	sm_satellite_radius_03		= CreateConVar("sm_satellite_radius_03","200.0", "Radius of Satellite cannon (Mode:INFERNO)", FCVAR_NOTIFY);
	sm_satellite_limit_01		= CreateConVar("sm_satellite_limit_01","15", "Frequency limitation in one round (Mode:JUDGEMENT)", FCVAR_NOTIFY);
	sm_satellite_limit_02		= CreateConVar("sm_satellite_limit_02","10", "Frequency limitation in one round (Mode:BLIZZARD)", FCVAR_NOTIFY);
	sm_satellite_limit_03		= CreateConVar("sm_satellite_limit_03","10", "Frequency limitation in one round (Mode:INFERNO)", FCVAR_NOTIFY);
	sm_satellite_height			= CreateConVar("sm_satellite_height","650", "Height of launching point", FCVAR_NOTIFY);
	sm_satellite_adminonly		= CreateConVar("sm_satellite_adminonly","0", "Admin only (0:OFF 1:ON), match 'magnum_satellite' FLAG", FCVAR_NOTIFY);
	sm_satellite_adminunlimit	= CreateConVar("sm_satellite_adminunlimit","0", "Admin remove limitation (0:OFF 1:ON), match 'magnum_satellite_unlimit' FLAG", FCVAR_NOTIFY);
	
	HookEvent("weapon_fire", Event_Weapon_Fire);
	HookEvent("item_pickup", Event_Item_Pickup);
	HookEvent("round_start", Event_Round_Start);
	
	hActiveWeapon = FindSendPropInfo ("CTerrorPlayer", "m_hActiveWeapon");
	m_iClip1 = FindSendPropInfo("CBaseCombatWeapon", "m_iClip1");
	
	AutoExecConfig(true,"l4d2_satellite");
}

/******************************************************
*	Initial functions
*******************************************************/
public OnMapStart()
{
	ResetParameter();
	
	/* Precache models */
	PrecacheModel(ENTITY_PROPANE, true);
	PrecacheModel(ENTITY_GASCAN, true);
	
	g_BeamSprite = PrecacheModel(SPRITE_BEAM);
	g_HaloSprite = PrecacheModel(SPRITE_HALO);
	g_GlowSprite = PrecacheModel(SPRITE_GLOW);
	PrecacheParticle(PARTICLE_FIRE01);
	PrecacheParticle(PARTICLE_FIRE02);
	
	/* Precache sounds */
	PrecacheSound(SOUND_NEGATIVE, true);
	PrecacheSound(SOUND_SHOOT01, true);
	PrecacheSound(SOUND_SHOOT02, true);
	PrecacheSound(SOUND_SHOOT03, true);
	PrecacheSound(SOUND_SHOOT04, true);
	PrecacheSound(SOUND_SHOOT05, true);
	PrecacheSound(SOUND_SHOOT06, true);
	PrecacheSound(SOUND_SHOOT07, true);
	PrecacheSound(SOUND_SHOOT08, true);
	PrecacheSound(SOUND_SHOOT09, true);
	PrecacheSound(SOUND_TRACING, true);
	PrecacheSound(SOUND_IMPACT01, true);
	PrecacheSound(SOUND_IMPACT02, true);
	PrecacheSound(SOUND_IMPACT03, true);
	PrecacheSound(SOUND_FREEZE, true);
	PrecacheSound(SOUND_DEFROST, true);
}

public Action:Event_Round_Start(Handle:event, const String:name[], bool:dontBroadcast)
{
	ResetParameter();
}

public ResetParameter()
{
	for(new i = 0; i < MAXPLAYERS+1; i++)
	{
		energy[i][MODE_JUDGEMENT] = GetConVarInt(sm_satellite_limit_01);
		energy[i][MODE_BLIZZARD] = GetConVarInt(sm_satellite_limit_02);
		energy[i][MODE_INFERNO] = GetConVarInt(sm_satellite_limit_03);
	}
	for(new j = 0; j < MAXPLAYERS+1; j++)
		freeze[j] = OFF;
}

/******************************************************
*	Event when using magnum pistol
*******************************************************/	
public Action:Event_Weapon_Fire(Handle:event, const String:name[], bool:dontBroadcast)
{
	decl String:mode[16];
	GetConVarString(FindConVar("mp_gamemode"), mode, sizeof(mode));
	if(StrEqual(mode, "versus"))
		return;
	
	new attacker = GetClientOfUserId(GetEventInt(event, "userid"));
	decl String:weapon[64];
	GetEventString(event, "weapon", weapon, sizeof(weapon));
	
	/* Admin only? */
	if (GetConVarInt(sm_satellite_adminonly) && !HasSatelliteAccess(attacker))
		return;
	
	if (StrEqual(weapon, "pistol_magnum") &&
		GetConVarInt(sm_satellite_enable) && operation[attacker] > 0)
	{
		/* Bot can't use */
		if(GetClientTeam(attacker) != SURVIVOR || IsFakeClient(attacker))
			return;
		
		/* Check energy */
		if(energy[attacker][operation[attacker]] <= 0)
		{
			PrintHintText(attacker, MESSAGE_EMPTY);
			operation[attacker] = MODE_SLEEP;
			return;
		}
		
		/* Emit sound */
		new soundNo = GetRandomInt(1, 9);
		if(soundNo == 1)  EmitSoundToAll(SOUND_SHOOT01, attacker);
		else if(soundNo == 2)  EmitSoundToAll(SOUND_SHOOT02, attacker);
		else if(soundNo == 3)  EmitSoundToAll(SOUND_SHOOT03, attacker);
		else if(soundNo == 4)  EmitSoundToAll(SOUND_SHOOT04, attacker);
		else if(soundNo == 5)  EmitSoundToAll(SOUND_SHOOT05, attacker);
		else if(soundNo == 6)  EmitSoundToAll(SOUND_SHOOT06, attacker);
		else if(soundNo == 7)  EmitSoundToAll(SOUND_SHOOT07, attacker);
		else if(soundNo == 8)  EmitSoundToAll(SOUND_SHOOT08, attacker);
		else if(soundNo == 9)  EmitSoundToAll(SOUND_SHOOT09, attacker);
		
		/* Trace and show effect */
		GetTracePosition(attacker);
		EmitAmbientSound(SOUND_TRACING, trsPos[attacker]);
		CreateLaserEffect(attacker, 150, 150, 230, 230, 0.5, 0.2, NORMAL);
		CreateSparkEffect(attacker, 1200, 5);
		
		/* Ready to launch */
		CreateTimer(0.2, TraceTimer, attacker);
		
		/* Reload compulsorily */
		new wData = GetEntDataEnt2(attacker, hActiveWeapon);
		SetEntData(wData, m_iClip1, 0);
	}
}

public Action:Event_Item_Pickup(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new String:item[64];
	GetEventString(event, "item", item, sizeof(item));
	
	if (StrEqual(item, "pistol_magnum") &&
		GetConVarInt(sm_satellite_enable) &&
		IsClientInGame(client) && !IsFakeClient(client))
	{
		/* Display hint how to switch mode */
		ClientCommand(client, "gameinstructor_enable 1");
		CreateTimer(0.3, DisplayInstructorHint, client);
		operation[client] = MODE_SLEEP;
	}
}

public Action:OnPlayerRunCmd(client, &buttons)
{
	if(IsClientInGame(client) && IsPlayerAlive(client))
	{
		if(GetClientTeam(client) != SURVIVOR)
			return;
		
		/* Admin only? */
		if (GetUserAdmin(client) == INVALID_ADMIN_ID &&
			GetConVarInt(sm_satellite_adminonly))
			return;
		
		/* If freezing, block mouse operation */
		if(freeze[client] == ON)
		{
			if(buttons & IN_ATTACK)
				buttons &= ~IN_ATTACK;
			if(buttons & IN_ATTACK2)
				buttons &= ~IN_ATTACK2;
		}
		
		/* When zoom key is pushed */
		if(buttons & IN_ZOOM)
		{
			decl String:weapon[64];
			GetClientWeapon(client, weapon, 64);
			
			if (StrEqual(weapon, "weapon_pistol_magnum") &&
				GetConVarInt(sm_satellite_enable))
			{
				/* Check client Access */
				if (GetConVarInt(sm_satellite_adminonly) && !HasSatelliteAccess(client))
					return;
				/* Mode change menu */
				ChangeMode(client);
			}
		}
	}
}

public ChangeMode(client)
{
	new String:mStrJud[64], String:mStrBli[64], String:mStrInf[64];
	Format(mStrJud, sizeof(mStrJud), "MODE: JUDGEMENT (Energy: %d)", energy[client][MODE_JUDGEMENT]);
	Format(mStrBli, sizeof(mStrBli), "MODE: BLIZZARD  (Energy: %d)", energy[client][MODE_BLIZZARD]);
	Format(mStrInf, sizeof(mStrInf), "MODE: INFERNO   (Energy: %d)", energy[client][MODE_INFERNO]);
	if (GetConVarInt(sm_satellite_adminunlimit) && HasSatelliteUnlimitAccess(client))
	{
		Format(mStrJud, sizeof(mStrJud), "MODE: JUDGEMENT (Energy: Unlimited)");
		Format(mStrBli, sizeof(mStrBli), "MODE: BLIZZARD  (Energy: Unlimited)");
		Format(mStrInf, sizeof(mStrInf), "MODE: INFERNO   (Energy: Unlimited)");
	}

	new Handle:menu = CreateMenu(ChangeModeMenu);
	SetMenuTitle(menu, "*** Operation:Satellite System ***");
	AddMenuItem(menu, "0", mStrJud);
	AddMenuItem(menu, "1", mStrBli);
	AddMenuItem(menu, "2", mStrInf);
	AddMenuItem(menu, "3", "SLEEP");
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, 10);
}

public ChangeModeMenu(Handle:menu, MenuAction:action, client, itemNum)
{
	if(action == MenuAction_Select)
	{
		switch(itemNum)
		{
			case 0:
				operation[client] = MODE_JUDGEMENT;
			case 1:
				operation[client] = MODE_BLIZZARD;
			case 2:
				operation[client] = MODE_INFERNO;
			case 3:
				operation[client] = MODE_SLEEP;
		}
		if(itemNum != 3 && energy[client][itemNum+1] <= 0)
		{
			PrintHintText(client, MESSAGE_EMPTY);
			EmitSoundToClient(client, SOUND_NEGATIVE);
			operation[client] = MODE_SLEEP;
		}
		else
		{
			switch(itemNum)
			{
				case 0:
					{
					operation[client] = MODE_JUDGEMENT;
					PrintHintText(client, MESSAGE_SHIFT_JUDGEMENT);
					}
				case 1:
					{
					operation[client] = MODE_BLIZZARD;
					PrintHintText(client, MESSAGE_SHIFT_BLIZZARD);
					}
				case 2:
					{
					operation[client] = MODE_INFERNO;
					PrintHintText(client, MESSAGE_SHIFT_INFERNO);
					}
				case 3:
					{
					operation[client] = MODE_SLEEP;
					PrintHintText(client, MESSAGE_SHIFT_SLEEP);
					}
			}
			EmitSoundToClient(client, SOUND_SHOOT02);
		}
	}
}

/******************************************************
*	Timer functions about launching
*******************************************************/
public Action:TraceTimer(Handle:timer, any:client)
{
	/* Ring laser effect */
	CreateRingEffect(client, 150, 150, 230, 230, 2.0,
				GetConVarFloat(sm_satellite_burst_delay));
	
	/* Launch satellite cannon */
	raycount[client] = 0;
	ticket[client] = 0;
	
	/* If ducking, three laser launched */
	if( (GetEntityFlags(client) & FL_DUCKING) &&
		(GetEntityFlags(client) & FL_ONGROUND))
		ticket[client] = 1;
	
	CreateTimer(GetConVarFloat(sm_satellite_burst_delay),
				SatelliteTimer, client);
}

public Action:SatelliteTimer(Handle:timer, any:client)
{
	if(!IsValidEntity(client) || !IsClientInGame(client) || !IsPlayerAlive(client))
		return;
	
	if (operation[client] != MODE_JUDGEMENT &&
		operation[client] != MODE_BLIZZARD &&
		operation[client] != MODE_INFERNO)
			operation[client] = MODE_JUDGEMENT;
	
	/* Mode: JUDGEMENT */
	if(operation[client] == MODE_JUDGEMENT)
	{
		Judgement(client);
		if(raycount[client] == 0)
			energy[client][MODE_JUDGEMENT]--;
		if(GetConVarInt(sm_satellite_adminunlimit) && HasSatelliteUnlimitAccess(client))
			energy[client][MODE_JUDGEMENT]++;
	}
	
	/* Mode: BLIZZARD */
	else if(operation[client] == MODE_BLIZZARD)
	{
		Blizzard(client);
		energy[client][MODE_BLIZZARD]--;
		if(GetConVarInt(sm_satellite_adminunlimit) && HasSatelliteUnlimitAccess(client))
			energy[client][MODE_BLIZZARD]++;
		
	}
	
	/* Mode: INFERNO */
	else if(operation[client] == MODE_INFERNO)
	{
		Inferno(client);
		energy[client][MODE_INFERNO]--;
		if(GetConVarInt(sm_satellite_adminunlimit) && HasSatelliteUnlimitAccess(client))
			energy[client][MODE_INFERNO]++;
	}
	
	/* If energy becomes empty, display message */
	if(energy[client][operation[client]] <= 0)
	{
		PrintHintText(client, MESSAGE_EMPTY);
		operation[client] = MODE_SLEEP;
	}
}

public Judgement(client)
{
	decl Float:pos[3];
	
	/* Emit impact sound */
	EmitAmbientSound(SOUND_IMPACT01, trsPos[client]);
	
	/* Laser effect */
	CreateLaserEffect(client, 230, 230, 80, 230, 6.0, 1.0, VARTICAL);
	
	/* Damage to special infected */
	for(new i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i) || GetClientTeam(i) != 3)
			continue;
		GetClientAbsOrigin(i, pos);
		if(GetVectorDistance(pos, trsPos[client]) < GetConVarFloat(sm_satellite_radius_01))
		{
			DamageEffect(i, GetConVarFloat(sm_satellite_damage_01));
		}
	}
	/* Explode */
	LittleFlower(client, EXPLODE);
	
	/* Push away */
	PushAway(client, GetConVarFloat(sm_satellite_force),
			GetConVarFloat(sm_satellite_radius_01), 0.5);
	
	if(ticket[client] == 1)
	{
		raycount[client]++;
		if(raycount[client] >= 3)
		{
			ticket[client] = 0;
			raycount[client] = 0;
			return;
		}
		/* Set random offset position */
		MoveTracePosition(client, 50, 150);
		CreateTimer(0.17, SatelliteTimer, client);
	}
}

public Blizzard(client)
{
	decl Float:pos[3];
	
	/* Emit impact sound */
	EmitAmbientSound(SOUND_IMPACT01, trsPos[client]);
	EmitAmbientSound(SOUND_IMPACT02, trsPos[client]);
	
	/* Laser effect */
	CreateLaserEffect(client, 80, 80, 230, 230, 6.0, 1.0, VARTICAL);
	TE_SetupBeamRingPoint(trsPos[client], 10.0, GetConVarFloat(sm_satellite_radius_02),
						g_BeamSprite, g_HaloSprite, 0, 10, 0.3, 10.0, 0.5,
						{40, 40, 230, 230}, 400, 0);
	TE_SendToAll();
	
	/* Freeze special infected and survivor in the radius */
	for(new i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i))
			continue;
		GetClientEyePosition(i, pos);
		if(GetVectorDistance(pos, trsPos[client]) < GetConVarFloat(sm_satellite_radius_02))
		{
			if(GetEntProp(i, Prop_Send, "m_zombieClass") != 8)
				FreezePlayer(i, pos, GetConVarFloat(sm_satellite_freeze_02));
		}
	}
	
	/* Freeze infected in the radius */
	decl MaxEntities, String:mName[64], Float:entPos[3];
	
	MaxEntities = GetMaxEntities();
	for (new i = 1; i <= MaxEntities; i++)
	{
		if (IsValidEdict(i) && IsValidEntity(i))
		{
			GetEntPropString(i, Prop_Data, "m_ModelName", mName, sizeof(mName))
			if (StrContains(mName, "infected") != -1)
			{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", entPos)
				if (GetVectorDistance(trsPos[client], entPos) < GetConVarFloat(sm_satellite_radius_02))
				{
					EmitAmbientSound(SOUND_FREEZE, entPos, i, SNDLEVEL_RAIDSIREN);
					TE_SetupGlowSprite(entPos, g_GlowSprite, 5.0, 3.0, 130);
					TE_SendToAll();
					DamageEffect(i, 100.0);
				}
			}
		}
	}
	/* Push away */
	PushAway(client, GetConVarFloat(sm_satellite_force),
			GetConVarFloat(sm_satellite_radius_02), 0.5);
}

public Inferno(client)
{
	decl Float:pos[3];
	
	/* Emit impact sound */
	EmitAmbientSound(SOUND_IMPACT01, trsPos[client]);
	EmitAmbientSound(SOUND_IMPACT03, trsPos[client]);
	
	/* Laser effect */
	CreateLaserEffect(client, 230, 40, 40, 230, 6.0, 1.0, VARTICAL);
	ShowParticle(trsPos[client], PARTICLE_FIRE01, 3.0);
	ShowParticle(trsPos[client], PARTICLE_FIRE02, 3.0);
	
	/* Ignite special infected and survivor in the radius */
	for(new i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i))
			continue;
		GetClientEyePosition(i, pos);
		if(GetVectorDistance(pos, trsPos[client]) < GetConVarFloat(sm_satellite_radius_03))
		{
			if(GetClientTeam(i) == SURVIVOR)
			{
				ScreenFade(i, 200, 0, 0, 150, 80, 1);
				DamageEffect(i, 5.0);
			}
			else if(GetClientTeam(i) == INFECTED)
			{
				IgniteEntity(i, 10.0);
				DamageEffect(i, GetConVarFloat(sm_satellite_damage_03));
			}
		}
	}
	
	/* Ignite infected in the radius */
	decl MaxEntities, String:mName[64], Float:entPos[3];
	
	MaxEntities = GetMaxEntities();
	for (new i = 1; i <= MaxEntities; i++)
	{
		if (IsValidEdict(i) && IsValidEntity(i))
		{
			GetEntPropString(i, Prop_Data, "m_ModelName", mName, sizeof(mName))
			if (StrContains(mName, "infected") != -1)
			{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", entPos)
				entPos[2] += 50;
				if (GetVectorDistance(trsPos[client], entPos) < GetConVarFloat(sm_satellite_radius_03))
				{
					IgniteEntity(i, 10.0);
				}
			}
		}
	}
	/* Push away */
	PushAway(client, GetConVarFloat(sm_satellite_force),
			GetConVarFloat(sm_satellite_radius_03), 0.5);
}

public Action:DefrostPlayer(Handle:timer, any:entity)
{
	if(IsValidEdict(entity) && IsValidEntity(entity))
	{
		decl Float:entPos[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", entPos);
		EmitAmbientSound(SOUND_DEFROST, entPos, entity, SNDLEVEL_RAIDSIREN);
		SetEntityMoveType(entity, MOVETYPE_WALK);
		SetEntityRenderColor(entity, 255, 255, 255, 255);
		ScreenFade(entity, 0, 0, 0, 0, 0, 1);
		freeze[entity] = OFF;
	}
}

public Action:DeletePushForce(Handle:timer, any:ent)
{
	if (IsValidEntity(ent))
	{
		decl String:classname[64];
		GetEdictClassname(ent, classname, sizeof(classname));
		if (StrEqual(classname, "point_push", false))
		{
			AcceptEntityInput(ent, "Disable");
			AcceptEntityInput(ent, "Kill"); 
			RemoveEdict(ent);
		}
	}
}

/******************************************************
*	TE functions
*******************************************************/
public GetTracePosition(client)
{
	decl Float:myPos[3], Float:myAng[3], Float:tmpPos[3], Float:entPos[3];
	
	GetClientEyePosition(client, myPos);
	GetClientEyeAngles(client, myAng);
	new Handle:trace = TR_TraceRayFilterEx(myPos, myAng, CONTENTS_SOLID|CONTENTS_MOVEABLE, RayType_Infinite, TraceEntityFilterPlayer, client);
	if(TR_DidHit(trace))
	{
		tEntity = TR_GetEntityIndex(trace);
		GetEntPropVector(tEntity, Prop_Send, "m_vecOrigin", entPos);
		TR_GetEndPosition(tmpPos, trace);
	}
	CloseHandle(trace);
	for(new i = 0; i < 3; i++)
		trsPos[client][i] = tmpPos[i];
}

public MoveTracePosition(client, min, max)
{
	new point = GetRandomInt(1, 4);
	new xOffset = GetRandomInt(min, max);
	new yOffset = GetRandomInt(min, max);
	
	if(point == 1)
	{
		trsPos[client][0] -= xOffset;
		trsPos[client][1] += yOffset;
	}
	else if(point == 2)
	{
		trsPos[client][0] += xOffset;
		trsPos[client][1] += yOffset;
	}
	else if(point == 3)
	{
		trsPos[client][0] -= xOffset;
		trsPos[client][1] -= yOffset;
	}
	else if(point == 4)
	{
		trsPos[client][0] += xOffset;
		trsPos[client][1] -= yOffset;
	}
}

public bool:TraceEntityFilterPlayer(entity, contentsMask)
{
	return entity > MaxClients || !entity;
}

public CreateLaserEffect(client, colRed, colGre, colBlu, alpha, Float:width, Float:duration, mode)
{
	decl color[4];
	color[0] = colRed;
	color[1] = colGre;
	color[2] = colBlu;
	color[3] = alpha;
	
	if(mode == NORMAL)
	{
		/* Show laser between user and impact position */
		decl Float:myPos[3];
		
		GetClientEyePosition(client, myPos);
		TE_SetupBeamPoints(myPos, trsPos[client], g_BeamSprite, 0, 0, 0,
							duration, width, width, 1, 0.0, color, 0);
		TE_SendToAll();
	}
	else if(mode == VARTICAL)
	{
		/* Show laser like lightning bolt */
		decl Float:lchPos[3];
		
		for(new i = 0; i < 3; i++)
			lchPos[i] = trsPos[client][i];
		lchPos[2] += GetConVarInt(sm_satellite_height);
		TE_SetupBeamPoints(lchPos, trsPos[client], g_BeamSprite, 0, 0, 0,
							duration, width, width, 1, 2.0, color, 0);
		TE_SendToAll();
		TE_SetupGlowSprite(lchPos, g_GlowSprite, 1.5, 2.8, 230);
		TE_SendToAll();
	}
}

public CreateRingEffect(client, colRed, colGre, colBlu, alpha, Float:width, Float:duration)
{
	decl color[4];
	color[0] = colRed;
	color[1] = colGre;
	color[2] = colBlu;
	color[3] = alpha;
	
	TE_SetupBeamRingPoint(trsPos[client], 300.0, 10.0, g_BeamSprite,
						g_HaloSprite, 0, 10, 1.2, 4.0, 0.5,
						{150, 150, 230, 230}, 80, 0);
	TE_SendToAll();
}

public CreateSparkEffect(client, size, length)
{
	decl Float:spkVec[3];
	spkVec[0]=GetRandomFloat(-1.0, 1.0);
	spkVec[1]=GetRandomFloat(-1.0, 1.0);
	spkVec[2]=GetRandomFloat(-1.0, 1.0);
	
	TE_SetupSparks(trsPos[client], spkVec, size, length);
	TE_SendToAll();
}

/******************************************************
*	Other functions
*******************************************************/
stock DamageEffect(target, Float:damage)
{
	decl String:tName[20];
	Format(tName, 20, "target%d", target);
	new pointHurt = CreateEntityByName("point_hurt");
	DispatchKeyValue(target, "targetname", tName);
	DispatchKeyValueFloat(pointHurt, "Damage", damage);
	DispatchKeyValue(pointHurt, "DamageTarget", tName);
	DispatchKeyValue(pointHurt, "DamageType", "65536");
	DispatchSpawn(pointHurt);
	AcceptEntityInput(pointHurt, "Hurt");
	AcceptEntityInput(pointHurt, "Kill");
}

public PushAway(client, Float:force, Float:radius, Float:duration)
{
	new push = CreateEntityByName("point_push");
	DispatchKeyValueFloat (push, "magnitude", force);
	DispatchKeyValueFloat (push, "radius", radius);
	SetVariantString("spawnflags 24");
	AcceptEntityInput(push, "AddOutput");
	DispatchSpawn(push);
	TeleportEntity(push, trsPos[client], NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(push, "Enable", -1, -1);
	CreateTimer(duration, DeletePushForce, push);
}

public LittleFlower(client, type)
{
	/* Cause fire(type=0) or explosion(type=1) */
	new entity = CreateEntityByName("prop_physics");
	if (IsValidEntity(entity))
	{
		trsPos[client][2] += 20;
		if (type == 0)
			/* fire */
			DispatchKeyValue(entity, "model", ENTITY_GASCAN);
		else
			/* explode */
			DispatchKeyValue(entity, "model", ENTITY_PROPANE);
		DispatchSpawn(entity);
		SetEntData(entity, GetEntSendPropOffs(entity, "m_CollisionGroup"), 1, 1, true);
		TeleportEntity(entity, trsPos[client], NULL_VECTOR, NULL_VECTOR);
		AcceptEntityInput(entity, "break");
	}
}

public ScreenFade(target, red, green, blue, alpha, duration, type)
{
	new Handle:msg = StartMessageOne("Fade", target);
	BfWriteShort(msg, 500);
	BfWriteShort(msg, duration);
	if (type == 0)
		BfWriteShort(msg, (0x0002 | 0x0008));
	else
		BfWriteShort(msg, (0x0001 | 0x0010));
	BfWriteByte(msg, red);
	BfWriteByte(msg, green);
	BfWriteByte(msg, blue);
	BfWriteByte(msg, alpha);
	EndMessage();
}

public FreezePlayer(entity, Float:pos[3], Float:time)
{
	SetEntityMoveType(entity, MOVETYPE_NONE);
	SetEntityRenderColor(entity, 0, 128, 255, 135);
	ScreenFade(entity, 0, 128, 255, 192, 2000, 1);
	EmitAmbientSound(SOUND_FREEZE, pos, entity, SNDLEVEL_RAIDSIREN);
	TE_SetupGlowSprite(pos, g_GlowSprite, time, 0.5, 130);
	TE_SendToAll();
	freeze[entity] = ON;
	CreateTimer(time, DefrostPlayer, entity);
}

/******************************************************
*	Particle control functions
*******************************************************/
public ShowParticle(Float:pos[3], String:particlename[], Float:time)
{
	/* Show particle effect you like */
	new particle = CreateEntityByName("info_particle_system");
	if (IsValidEdict(particle))
	{
		TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);
		DispatchKeyValue(particle, "effect_name", particlename);
		DispatchKeyValue(particle, "targetname", "particle");
		DispatchSpawn(particle);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
		CreateTimer(time, DeleteParticles, particle);
	}  
}

public Action:DeleteParticles(Handle:timer, any:particle)
{
	/* Delete particle */
    if (IsValidEntity(particle))
	{
		new String:classname[64];
		GetEdictClassname(particle, classname, sizeof(classname));
		if (StrEqual(classname, "info_particle_system", false))
            RemoveEdict(particle);
	}
}

public PrecacheParticle(String:particlename[])
{
	/* Precache particle */
	new particle = CreateEntityByName("info_particle_system");
	if (IsValidEdict(particle))
	{
		DispatchKeyValue(particle, "effect_name", particlename);
		DispatchKeyValue(particle, "targetname", "particle");
		DispatchSpawn(particle);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
		CreateTimer(0.01, DeleteParticles, particle);
	}  
}

/******************************************************
*	Display hint functions
*******************************************************/
public Action:DisplayInstructorHint(Handle:timer, any:client)
{
	decl entity, String:tName[32], Handle:hRemovePack;
	
	entity = CreateEntityByName("env_instructor_hint");
	FormatEx(tName, sizeof(tName), "hint%d", client);
	
	DispatchKeyValue(client, "targetname", tName);
	DispatchKeyValue(entity, "hint_target", tName);
	DispatchKeyValue(entity, "hint_timeout", "5");
	DispatchKeyValue(entity, "hint_range", "0.01");
	DispatchKeyValue(entity, "hint_color", "255 255 255");
	DispatchKeyValue(entity, "hint_icon_onscreen", "use_binding");
	DispatchKeyValue(entity, "hint_caption", "Change mode");
	DispatchKeyValue(entity, "hint_binding", "+zoom");
	DispatchSpawn(entity);
	AcceptEntityInput(entity, "ShowHint");
	
	hRemovePack = CreateDataPack();
	WritePackCell(hRemovePack, client);
	WritePackCell(hRemovePack, entity);
	CreateTimer(5.0, RemoveInstructorHint, hRemovePack);
}
	
public Action:RemoveInstructorHint(Handle:timer, Handle:hPack)
{
	decl entity, client
	
	ResetPack(hPack, false)
	client = ReadPackCell(hPack)
	entity = ReadPackCell(hPack)
	CloseHandle(hPack)
	
	if (!client || !IsClientInGame(client))
		return;
	
	if (IsValidEntity(entity))
			RemoveEdict(entity)
	
	ClientCommand(client, "gameinstructor_enable 0")
	DispatchKeyValue(client, "targetname", "")
}

public bool:HasSatelliteAccess(int client)
{
	/* Checks valid player
	if (!IsValidPlayer (client))
		return false;
	*/

	// If player is not admin ...
	if (GetUserAdmin(client) == INVALID_ADMIN_ID)
		return false;
	
	if (CheckCommandAccess(client, "magnum_satellite", 0, true))
	{
		return true;
	}
	else
	{
		return false;
	}
}

public bool:HasSatelliteUnlimitAccess(int client)
{
	/* Checks valid player
	if (!IsValidPlayer (client))
		return false;
	*/

	// If player is not admin ...
	if (GetUserAdmin(client) == INVALID_ADMIN_ID)
		return false;
	
	if (CheckCommandAccess(client, "magnum_satellite_unlimit", 0, true))
	{
		return true;
	}
	else
	{
		return false;
	}
}

/******************************************************
*	EOF
*******************************************************/