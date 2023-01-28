/*
--------------------------------------------------------------
L4D2 Auto Infected Spawner 1.0.0
--------------------------------------------------------------
Manages its own system of automatic infected spawning.
--------------------------------------------------------------
*/

/*
TO DO:
- different max infected based on survivor count
- when spawn is full, use death event instead
- hook "mission_lost" event?
- use of queues?
*/
#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <colors>

#define PLUGIN_VERSION "1.0"

#define DEBUG_GENERAL 0
#define DEBUG_TIMES 0
#define DEBUG_SPAWNS 0
#define DEBUG_WEIGHTS 0
#define DEBUG_EVENTS 0

// Uncommons Debug
//#define DEBUG 1


#define MAX_INFECTED 28
#define NUM_TYPES_INFECTED 7

#define TEAM_SPECTATOR		1
#define TEAM_SURVIVORS 		2
#define TEAM_INFECTED 		3

//pz constants (for SI type checking)
#define IS_SMOKER	1
#define IS_BOOMER	2
#define IS_HUNTER	3
#define IS_SPITTER	4
#define IS_JOCKEY	5
#define IS_CHARGER	6
#define IS_TANK		8

//pz constants (for spawning)
#define SI_SMOKER		0
#define SI_BOOMER		1
#define SI_HUNTER		2
#define SI_SPITTER		3
#define SI_JOCKEY		4
#define SI_CHARGER		5
#define SI_TANK			6

//pzconstants (for Tank Class)
#define ZOMBIECLASS_TANK	8

//make sure spawn names and ordering match pz constants
new String:Spawns[NUM_TYPES_INFECTED][16] = {"smoker auto","boomer auto","hunter auto","spitter auto","jockey auto","charger auto","tank auto"};

new SICount;
new SILimit;
new SpawnSize;
new SpawnSizeOnPlayer;
new SpawnSizeAddAmount;
new AliveSurvivors;
new SpawnTimeMode;
new GameMode;

new SpawnTimeOnPlayer;
new Float:SpawnTimeReduceAmount;
new Float:SpawnTimeMin;
new Float:SpawnTimeMax;
new Float:SpawnTimes[MAX_INFECTED+1];

new SpawnWeights[NUM_TYPES_INFECTED];
new SpawnLimits[NUM_TYPES_INFECTED];
new SpawnCounts[NUM_TYPES_INFECTED];
new Handle:hSpawnWeights[NUM_TYPES_INFECTED];
new Handle:hSpawnLimits[NUM_TYPES_INFECTED];
new Float:IntervalEnds[NUM_TYPES_INFECTED];

new bool:Enabled;
new bool:SpawnSIWithTank;
new bool:EventsHooked;
new bool:SafeRoomChecking;
new bool:FasterResponse;
new bool:FasterSpawn;
new bool:SafeSpawn;
new bool:ScaleWeights;
new bool:ChangeByConstantTime;
new bool:SpawnTimerStarted;
new bool:WitchTimerStarted;
new bool:WitchWaitTimerStarted;
new bool:WitchCountFull;
new bool:RoundStarted;
new bool:RoundEnded;
new bool:LeftSafeRoom;

new bool:HaveTank;

new Handle:hEnabled;
new Handle:hSpawnSIWithTank;
new Handle:hDisableInVersus;
new Handle:hFasterResponse;
new Handle:hFasterSpawn;
new Handle:hSafeSpawn;
new Handle:hSILimit;
new Handle:hSILimitMax;
new Handle:hScaleWeights;
new Handle:hSpawnSize;
new Handle:hSpawnSizeOnPlayer;
new Handle:hSpawnSizeAddAmount;
new Handle:hSpawnTimeOnPlayer;
new Handle:hSpawnTimeReduceAmount;
new Handle:hSpawnTimeMin;
new Handle:hSpawnTimeMax;
new Handle:hSpawnTimer;
new Handle:hSpawnTimeMode;
new Handle:hGameMode;

new WitchCount;
new WitchLimit;
new Float:WitchPeriod;
new bool:VariableWitchPeriod;
new Handle:hWitchLimit;
new Handle:hWitchPeriod;
new Handle:hWitchPeriodMode;
new Handle:hWitchTimer;
new Handle:hWitchWaitTimer;



// Uncommons


public Plugin:myinfo =  
{
	name = "L4D2 Auto Infected Spawner",
	author = "Tordecybombo, FuzzOne - miniupdate ,TacKLER - miniupdate again, Zakikun - feature adding",
	description = "Custom automatic infected spawner",
	version = PLUGIN_VERSION,
	url = "https://github.com/wyxls/SourceModPlugins-L4D2"
};

public OnPluginStart()
{
	new Handle:surv_l = FindConVar("survivor_limit");
	SetConVarBounds(surv_l , ConVarBound_Upper, true, 8.0);

	new Handle:zombie_player_l = FindConVar("z_max_player_zombies");
	SetConVarBounds(zombie_player_l , ConVarBound_Upper, true, 8.0);
	SetConVarBounds(FindConVar("z_max_player_zombies"), ConVarBound_Upper, false);

	new Handle:zombie_minion_l = FindConVar("z_minion_limit");
	SetConVarBounds(zombie_minion_l , ConVarBound_Upper, true, 8.0);
	
	new Handle:zombie_surv = FindConVar("survival_max_specials");
	SetConVarBounds(zombie_surv , ConVarBound_Upper, true, 8.0);
	

	//l4d2 check
	decl String:mod[32];
	GetGameFolderName(mod, sizeof(mod));
	if(!StrEqual(mod, "left4dead2", false))
		SetFailState("[AIS] This plugin is for Left 4 Dead 2 only.");
	
	//hook events
	HookEvents();
	//witch events should not be unhooked to keep witch count working even when plugin is off
	HookEvent("witch_spawn", evtWitchSpawn);
	HookEvent("witch_killed", evtWitchKilled);
	//HookEvent("witch_harasser_set", evtWitchHarasse);
	
	//admin commands
	RegAdminCmd("l4d2_ais_debug", aisDebug, ADMFLAG_RCON, "Debug");
	RegAdminCmd("l4d2_ais_reset", ResetSpawns, ADMFLAG_RCON, "Reset by slaying all special infected and restarting the timer");
	RegAdminCmd("l4d2_ais_start", StartSpawnTimerManually, ADMFLAG_RCON, "Manually start the spawn timer");
	RegAdminCmd("l4d2_ais_time", SetConstantSpawnTime, ADMFLAG_CHEATS, "Set a constant spawn time (seconds) by setting l4d2_ais_time_min and l4d2_ais_time_max to the same value.");
	RegAdminCmd("l4d2_ais_preset", PresetWeights, ADMFLAG_CHEATS, "<default|none|boomer|smoker|hunter|tank|charger|jockey|spitter> Set spawn weights to given presets");
	
	//version cvar
	CreateConVar("l4d2_ais_version", PLUGIN_VERSION, "Auto Infected Spawner Version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	//console variables and handles
	hEnabled = CreateConVar("l4d2_ais_enabled", "1", "[0=OFF|1=ON] Disable/Enable functionality of the plugin", FCVAR_NONE, true, 0.0, true, 1.0);
	hSpawnSIWithTank = 	CreateConVar("l4d2_ais_spawn_si_with_tank", "0", "[0=OFF|1=ON] Disable/Enable Spawning Special Infected while Tank is alive", FCVAR_NONE, true, 0.0, true, 1.0);
	hDisableInVersus = CreateConVar("l4d2_ais_disable_in_versus", "1", "[0=OFF|1=ON] Automatically disable plugin in versus mode", FCVAR_NONE, true, 0.0, true, 1.0);
	hFasterResponse = CreateConVar("l4d2_ais_fast_response", "0", "[0=OFF|1=ON] Disable/Enable faster special infected response", FCVAR_NONE, true, 0.0, true, 1.0);
	hFasterSpawn = CreateConVar("l4d2_ais_fast_spawn", "0", "[0=OFF|1=ON] Disable/Enable faster special infected spawn (Enable when SI spawn rate is high)", FCVAR_NONE, true, 0.0, true, 1.0);
	hSafeSpawn = CreateConVar("l4d2_ais_safe_spawn", "0", "[0=OFF|1=ON] Disable/Enable special infected spawning while survivors are in safe room", FCVAR_NONE, true, 0.0, true, 1.0);
	hSpawnWeights[SI_BOOMER] = CreateConVar("l4d2_ais_boomer_weight", "100", "The weight for a boomer spawning", FCVAR_NONE, true, 0.0);
	hSpawnWeights[SI_HUNTER] = CreateConVar("l4d2_ais_hunter_weight", "100", "The weight for a hunter spawning", FCVAR_NONE, true, 0.0);
	hSpawnWeights[SI_SMOKER] = CreateConVar("l4d2_ais_smoker_weight", "100", "The weight for a smoker spawning", FCVAR_NONE, true, 0.0);
	hSpawnWeights[SI_TANK] = CreateConVar("l4d2_ais_tank_weight", "-1", "[-1 = Director spawns tanks] The weight for a tank spawning", FCVAR_NONE, true, -1.0);
	hSpawnWeights[SI_CHARGER] = CreateConVar("l4d2_ais_charger_weight", "100", "The weight for a charger spawning", FCVAR_NONE, true, 0.0);
	hSpawnWeights[SI_JOCKEY] = CreateConVar("l4d2_ais_jockey_weight", "100", "The weight for a jockey spawning", FCVAR_NONE, true, 0.0);
	hSpawnWeights[SI_SPITTER] = CreateConVar("l4d2_ais_spitter_weight", "100", "The weight for a spitter spawning", FCVAR_NONE, true, 0.0);
	hSpawnLimits[SI_BOOMER] = CreateConVar("l4d2_ais_boomer_limit", "1", "The max amount of boomers present at once", FCVAR_NONE, true, 0.0, true, 14.0);
	hSpawnLimits[SI_HUNTER] = CreateConVar("l4d2_ais_hunter_limit", "1", "The max amount of hunters present at once", FCVAR_NONE, true, 0.0, true, 14.0);
	hSpawnLimits[SI_SMOKER] = CreateConVar("l4d2_ais_smoker_limit", "1", "The max amount of smokers present at once", FCVAR_NONE, true, 0.0, true, 14.0);
	hSpawnLimits[SI_TANK] = CreateConVar("l4d2_ais_tank_limit", "0", "The max amount of tanks present at once", FCVAR_NONE, true, 0.0, true, 14.0);
	hSpawnLimits[SI_CHARGER] = CreateConVar("l4d2_ais_charger_limit", "1", "The max amount of chargers present at once", FCVAR_NONE, true, 0.0, true, 14.0);
	hSpawnLimits[SI_JOCKEY] = CreateConVar("l4d2_ais_jockey_limit", "1", "The max amount of jockeys present at once", FCVAR_NONE, true, 0.0, true, 14.0);
	hSpawnLimits[SI_SPITTER] = CreateConVar("l4d2_ais_spitter_limit", "1", "The max amount of spitters present at once", FCVAR_NONE, true, 0.0, true, 14.0);
	hScaleWeights = CreateConVar("l4d2_ais_scale_weights", "0", "[0=OFF|1=ON] Scale spawn weights with the limits of corresponding SI", FCVAR_NONE, true, 0.0, true, 1.0);
	hWitchLimit = CreateConVar("l4d2_ais_witch_limit", "-1", "[-1 = Director spawns witches] The max amount of witches present at once (independant of l4d2_ais_limit).", FCVAR_NONE, true, -1.0, true, 100.0);
	hWitchPeriod = CreateConVar("l4d2_ais_witch_period", "300.0", "The time (seconds) interval in which exactly one witch will spawn", FCVAR_NONE, true, 1.0);
	hWitchPeriodMode = CreateConVar("l4d2_ais_witch_period_mode", "1", "The witch spawn rate consistency [0=CONSTANT|1=VARIABLE]", FCVAR_NONE, true, 0.0, true, 1.0);
	hSILimit = CreateConVar("l4d2_ais_limit", "8", "The max amount of special infected at once", FCVAR_NONE, true, 1.0, true, float(MAX_INFECTED));
	hSILimitMax = FindConVar("z_max_player_zombies");
	hSpawnSize = CreateConVar("l4d2_ais_spawn_size", "2", "The amount of special infected spawned at each spawn interval", FCVAR_NONE, true, 1.0, true, float(MAX_INFECTED));
	hSpawnSizeOnPlayer = CreateConVar("l4d2_ais_spawn_size_on_player", "1", "The amount of special infected spawned based on alive player? [0=off|1=on]", FCVAR_NONE, true, 0.0, true, 1.0);
	hSpawnSizeAddAmount = CreateConVar("l4d2_ais_spawn_size_add_amount", "1", "The amount of special infected being added per alive player", FCVAR_NONE, true, 1.0, true, 4.0);
	hSpawnTimeMode = CreateConVar("l4d2_ais_time_mode", "1", "The spawn time mode [0=RANDOMIZED|1=INCREMENTAL|2=DECREMENTAL]", FCVAR_NONE, true, 0.0, true, 2.0);
	//hSpawnTimeFunction = CreateConVar("l4d2_ais_time_function", "0", "The spawn time function [0=LINEAR|1=EXPONENTIAL|2=LOGARITHMIC]", FCVAR_NONE, true, 0.0, true 2.0);
	hSpawnTimeOnPlayer = CreateConVar("l4d2_ais_time_on_player", "1", "The maximum auto spawn time being reduced based on alive player? [0=off|1=on]", FCVAR_NONE, true, 0.0, true, 1.0);
	hSpawnTimeReduceAmount = CreateConVar("l4d2_ais_time_reduce_amount", "5.0", "The amount of auto spawn time being reduced per alive player", FCVAR_NONE, true, 0.0);
	hSpawnTimeMin = CreateConVar("l4d2_ais_time_min", "20.0", "The minimum auto spawn time (seconds) for infected", FCVAR_NONE, true, 0.0);
	hSpawnTimeMax = CreateConVar("l4d2_ais_time_max", "60.0", "The maximum auto spawn time (seconds) for infected", FCVAR_NONE, true, 1.0);
	hGameMode = FindConVar("mp_gamemode");
	
	//hook cvar changes to variables
	HookConVarChange(hEnabled, ConVarEnabled);
	HookConVarChange(hSpawnSIWithTank,ConVarSpawnSIWithTank);
	HookConVarChange(hFasterResponse, ConVarFasterResponse);
	HookConVarChange(hFasterSpawn, ConVarFasterSpawn);
	HookConVarChange(hSafeSpawn, ConVarSafeSpawn);
	HookConVarChange(hScaleWeights, ConVarScaleWeights);
	HookConVarChange(hSILimit, ConVarSILimit);
	HookConVarChange(hSpawnSize, ConVarSpawnSize);
	HookConVarChange(hSpawnSizeOnPlayer, ConVarSpawnSizeOnPlayer);
	HookConVarChange(hSpawnSizeAddAmount, ConVarSpawnSizeAddAmount);
	HookConVarChange(hSpawnTimeMode, ConVarSpawnTimeMode);
	HookConVarChange(hSpawnTimeOnPlayer, ConVarSpawnTimeOnPlayer);
	HookConVarChange(hSpawnTimeReduceAmount, ConVarSpawnTimeReduceAmount);
	HookConVarChange(hSpawnTimeMin, ConVarSpawnTime);
	HookConVarChange(hSpawnTimeMax, ConVarSpawnTime);
	HookConVarChangeSpawnWeights(); //hooks all SI weights
	HookConVarChangeSpawnLimits();
	HookConVarChange(hGameMode, ConVarGameMode);
	HookConVarChange(hWitchLimit, ConVarWitchLimit);
	HookConVarChange(hWitchPeriod, ConVarWitchPeriod);
	HookConVarChange(hWitchPeriodMode, ConVarWitchPeriodMode);

	//set console variables
	EnabledCheck(); //sets Enabled, FasterResponse, FasterSpawn, and cvars
	SpawnSIWithTank = GetConVarBool(hSpawnSIWithTank);
	SafeSpawn = GetConVarBool(hSafeSpawn);
	SILimit = GetConVarInt(hSILimit);
	SpawnSize = GetConVarInt(hSpawnSize);
	SpawnSizeOnPlayer = GetConVarInt(hSpawnSizeOnPlayer);
	SpawnSizeAddAmount = GetConVarInt(hSpawnSizeAddAmount);
	SpawnTimeMode = GetConVarInt(hSpawnTimeMode);
	SpawnTimeOnPlayer = GetConVarInt(hSpawnTimeOnPlayer);
	SpawnTimeReduceAmount = GetConVarFloat(hSpawnTimeReduceAmount);
	SetSpawnTimes(); //sets SpawnTimeMin, SpawnTimeMax, and SpawnTimes[]
	SetSpawnWeights(); //sets SpawnWeights[]
	SetSpawnLimits(); //sets SpawnLimits[]
	WitchLimit = GetConVarInt(hWitchLimit);
	WitchPeriod = GetConVarFloat(hWitchPeriod);
	VariableWitchPeriod = GetConVarBool(hWitchPeriodMode);
	
	//set other variables
	ChangeByConstantTime = false;
	RoundStarted = false;
	RoundEnded = false;
	LeftSafeRoom = false;
	HaveTank = false;
	
	//autoconfig executed on every map change
	AutoExecConfig(true, "l4d2_autoIS");
}

public OnConfigsExecuted()
{
	SetCvars(); //refresh cvar settings in case they change
	GameModeCheck();
	
	if (GameMode == 2 && GetConVarBool(hDisableInVersus)) //disable in versus
		SetConVarBool(hEnabled, false);
}

public OnClientConnected(client)
{
	if (IsFakeClient(client))
	{
		return;
	}
	SurvivorCheck();
	AliveSurvivors++;
	SetSpawnSizeOnPlayer();
	SetSpawnTimeOnPlayer();
	CPrintToChatAll ("{green}[autoIS] {lightgreen}玩家加入, 存活玩家数量为{olive}%i{lightgreen}, 特感数量改为{olive}%i{lightgreen}", AliveSurvivors, SpawnSize);
	CPrintToChatAll ("{green}[autoIS] {lightgreen}当前特感刷新间隔{olive}[%.2f, %.2f]{lightgreen}秒", SpawnTimeMin, SpawnTimeMax);
}

public OnClientDisconnect(client)
{
	if (IsFakeClient(client))
	{
		return;
	}
	SurvivorCheck();
	SetSpawnSizeOnPlayer();
	SetSpawnTimeOnPlayer();
	CPrintToChatAll ("{green}[autoIS] {lightgreen}玩家离开, 存活玩家数量为{olive}%i{lightgreen}, 特感数量改为{olive}%i{lightgreen}", AliveSurvivors, SpawnSize);
	CPrintToChatAll ("{green}[autoIS] {lightgreen}当前特感刷新间隔{olive}[%.2f, %.2f]{lightgreen}秒", SpawnTimeMin, SpawnTimeMax);
}

HookEvents()
{
	if (!EventsHooked)
	{
		EventsHooked = true;
		//MI 5, We hook the round_start (and round_end) event on plugin start, since it occurs before map_start
		HookEvent("round_start", evtRoundStart, EventHookMode_Post);
		HookEvent("round_end", evtRoundEnd, EventHookMode_Pre);

		//hook the events that relative to spawnsize
		HookEvent("player_spawn", evtPlayerSpawn);
		HookEvent("tank_spawn", evtTankSpawn, EventHookMode_Pre);
		HookEvent("player_death", evtPlayerDeath);
		HookEvent("survivor_rescued", evtSurvivorRescued);
		HookEvent("player_team", evtPlayerTeam);

		//hook other events
		HookEvent("map_transition", evtRoundEnd, EventHookMode_Pre); //also stop spawn timers upon map transition
		HookEvent("create_panic_event", evtSurvivalStart);
		HookEvent("player_death", evtInfectedDeath);
		#if DEBUG_EVENTS
		LogMessage("[AIS] Events Hooked");
		#endif
	}
}
UnhookEvents()
{
	if (EventsHooked)
	{
		EventsHooked = false;
		UnhookEvent("round_start", evtRoundStart, EventHookMode_Post);
		UnhookEvent("round_end", evtRoundEnd, EventHookMode_Pre);
		UnhookEvent("player_spawn", evtPlayerSpawn);
		UnhookEvent("player_death", evtPlayerDeath);
		UnhookEvent("survivor_rescued", evtSurvivorRescued);
		UnhookEvent("player_team", evtPlayerTeam);
		UnhookEvent("map_transition", evtRoundEnd, EventHookMode_Pre);
		UnhookEvent("create_panic_event", evtSurvivalStart);
		UnhookEvent("player_death", evtInfectedDeath);
		#if DEBUG_EVENTS
		LogMessage("[AIS] Events Unhooked");
		#endif
	}
}

HookConVarChangeSpawnWeights()
{
	for (new i = 0; i < NUM_TYPES_INFECTED; i++)
		HookConVarChange(hSpawnWeights[i], ConVarSpawnWeights);
}

HookConVarChangeSpawnLimits()
{
	for (new i = 0; i < NUM_TYPES_INFECTED; i++)
		HookConVarChange(hSpawnLimits[i], ConVarSpawnLimits);
}

SetSpawnLimits()
{
	for (new i = 0; i < NUM_TYPES_INFECTED; i++)
		SpawnLimits[i] = GetConVarInt(hSpawnLimits[i]);
}

public ConVarEnabled(Handle:convar, const String:oldValue[], const String:newValue[])
{
	EnabledCheck();
}
public ConVarSpawnSIWithTank(Handle:convar, const String:oldValue[], const String:newValue[])
{
	SpawnSIWithTank = GetConVarBool(hSpawnSIWithTank);
	if(!SpawnSIWithTank)
	{
		StartTimers();
		//Notify all players that l4d2_ais_spawn_si_with_tank has changed to 0
		CPrintToChatAll("{green}[autoIS] {lightgreen}Tank在场时{olive}停止{lightgreen}生成特感");
	}
	else
	{
		StartTimers();
		//Notify all players that l4d2_ais_spawn_si_with_tank has changed to 1
		CPrintToChatAll("{green}[autoIS] {lightgreen}Tank在场时{olive}继续{lightgreen}生成特感");
	}
}
public ConVarFasterResponse(Handle:convar, const String:oldValue[], const String:newValue[])
{
	SetAIDelayCvars();
}
public ConVarFasterSpawn(Handle:convar, const String:oldValue[], const String:newValue[])
{
	SetAISpawnCvars();
}
public ConVarSafeSpawn(Handle:convar, const String:oldValue[], const String:newValue[])
{
	SafeSpawn = GetConVarBool(hSafeSpawn);
}
public ConVarScaleWeights(Handle:convar, const String:oldValue[], const String:newValue[])
{
	ScaleWeights = GetConVarBool(hScaleWeights);
}
public ConVarSILimit(Handle:convar, const String:oldValue[], const String:newValue[])
{
	SILimit = GetConVarInt(hSILimit); 
	CalculateSpawnTimes(); //must recalculate spawn time table to compensate for limit change
	if (LeftSafeRoom)
		StartSpawnTimer(); //restart timer after times change
}
public ConVarSpawnSize(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (SpawnSizeOnPlayer == 1)
	{
		SpawnSize = GetConVarInt(hSpawnSize) + SpawnSizeAddAmount * AliveSurvivors; 
	}
	else
	{
		SpawnSize = GetConVarInt(hSpawnSize);
	}
}
public ConVarSpawnSizeOnPlayer(Handle:convar, const String:oldValue[], const String:newValue[])
{
	SpawnSizeOnPlayer = GetConVarInt(hSpawnSizeOnPlayer);
	SurvivorCheck();
	if(SpawnSizeOnPlayer)
	{
		//Notify all players that l4d2_ais_spawn_size_on_player has changed to 1
		CPrintToChatAll("{green}[autoIS] {lightgreen}开启根据存活玩家数调整特感数量");
	}
	else
	{
		//Notify all players that l4d2_ais_spawn_size_on_player has changed to 0
		CPrintToChatAll("{green}[autoIS] {lightgreen}关闭根据存活玩家数调整特感数量");
	}
}
public ConVarSpawnSizeAddAmount(Handle:convar, const String:oldValue[], const String:newValue[])
{
	SpawnSizeAddAmount = GetConVarInt(hSpawnSizeAddAmount);
	//Notify all players that l4d2_ais_spawn_size_add_amount has changed to new value
	CPrintToChatAll("{green}[autoIS] {lightgreen}每一位存活玩家增加特感数量修改为 {olive}%i", SpawnSizeAddAmount);
	SurvivorCheck();
}
public ConVarSpawnTimeMode(Handle:convar, const String:oldValue[], const String:newValue[])
{
	SpawnTimeMode = GetConVarInt(hSpawnTimeMode);
	CalculateSpawnTimes(); //must recalculate spawn time table to compensate for mode change
	if (LeftSafeRoom)
		StartSpawnTimer(); //restart timer after times change
}
public ConVarSpawnTimeOnPlayer(Handle:convar, const String:oldValue[], const String:newValue[])
{
	SpawnTimeOnPlayer = GetConVarInt(hSpawnTimeOnPlayer);
	SurvivorCheck();
	if(SpawnTimeOnPlayer)
	{
		//Notify all players that l4d2_ais_time_on_player has changed to 1
		CPrintToChatAll("{green}[autoIS] {lightgreen}开启根据存活玩家数调整特感刷新间隔");
	}
	else
	{
		//Notify all players that l4d2_ais_time_on_player has changed to 0
		CPrintToChatAll("{green}[autoIS] {lightgreen}关闭根据存活玩家数调整特感刷新间隔");
	}
}
public ConVarSpawnTimeReduceAmount(Handle:convar, const String:oldValue[], const String:newValue[])
{
	SpawnTimeReduceAmount = GetConVarFloat(hSpawnTimeReduceAmount);
	//Notify all players that l4d2_ais_time_reduce_amount has changed to new value
	CPrintToChatAll("{green}[autoIS] {lightgreen}每一位存活玩家减少特感刷新间隔修改为 {olive}%.2f{lightgreen}秒", SpawnTimeReduceAmount);
	SurvivorCheck();
}
public ConVarSpawnTime(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (!ChangeByConstantTime)
		SetSpawnTimes();
}
public ConVarSpawnWeights(Handle:convar, const String:oldValue[], const String:newValue[])
{
	SetSpawnWeights();
	if (WitchLimit < 0 && SpawnWeights[SI_TANK] >= 0)
	{
		SetConVarInt(FindConVar("director_no_bosses"), 1);
		SetConVarInt(hWitchLimit, 0); 
	}
	else if (WitchLimit >= 0 && SpawnWeights[SI_TANK] < 0)
	{
		SetConVarInt(FindConVar("director_no_bosses"), 0);
		SetConVarInt(hWitchLimit, -1);
	}
}
public ConVarSpawnLimits(Handle:convar, const String:oldValue[], const String:newValue[])
{
	SetSpawnLimits();
}
public ConVarWitchLimit(Handle:convar, const String:oldValue[], const String:newValue[])
{
	WitchLimit = GetConVarInt(hWitchLimit);
	if (WitchLimit < 0 && SpawnWeights[SI_TANK] >= 0)
	{
		SetConVarInt(FindConVar("director_no_bosses"), 0);
		SetConVarInt(hSpawnWeights[SI_TANK], -1);
	}
	else if (WitchLimit >= 0 && SpawnWeights[SI_TANK] < 0)
	{
		SetConVarInt(FindConVar("director_no_bosses"), 1);
		SetConVarInt(hSpawnWeights[SI_TANK], 0);
	}
	if (LeftSafeRoom && WitchLimit > 0)
		RestartWitchTimer(0.0); //restart timer after times change
}
public ConVarWitchPeriod(Handle:convar, const String:oldValue[], const String:newValue[])
{
	WitchPeriod = GetConVarFloat(hWitchPeriod);
	if (LeftSafeRoom && WitchLimit > 0)
		RestartWitchTimer(0.0); //restart timer after times change
}
public ConVarWitchPeriodMode(Handle:convar, const String:oldValue[], const String:newValue[])
{
	VariableWitchPeriod = GetConVarBool(hWitchPeriodMode);
	if (LeftSafeRoom && WitchLimit > 0)
		RestartWitchTimer(0.0); //restart timer after times change
}
public ConVarGameMode(Handle:convar, const String:oldValue[], const String:newValue[])
{
	GameModeCheck();
}

EnabledCheck()
{
	Enabled = GetConVarBool(hEnabled);
	SetCvars();
	if (Enabled)
	{
		HookEvents();
		InitTimers();
	}
	else
		UnhookEvents();
	#if DEBUG_GENERAL
	LogMessage("[AIS] Plugin Enabled?: %b", Enabled);
	#endif
}

InitTimers()
{
	if (LeftSafeRoom)
	{
		StartTimers();
	}
	else if (GameMode != 3 && !SafeRoomChecking) //start safe room check in non-survival mode
	{
		SafeRoomChecking = true;
		CreateTimer(1.0, PlayerLeftStart);
	}
}

SetCvars()
{
	if (Enabled)
	{
		SetConVarBounds(hSILimitMax, ConVarBound_Upper, true, float(MAX_INFECTED));
		SetConVarFloat(hSILimitMax, float(MAX_INFECTED));
		SetConVarInt(FindConVar("z_boomer_limit"), 0);
		SetConVarInt(FindConVar("z_hunter_limit"), 0);
		SetConVarInt(FindConVar("z_smoker_limit"), 0);
		SetConVarInt(FindConVar("z_charger_limit"), 0);
		SetConVarInt(FindConVar("z_spitter_limit"), 0);
		SetConVarInt(FindConVar("z_jockey_limit"), 0);
		SetConVarInt(FindConVar("survival_max_boomers"), 0);
		SetConVarInt(FindConVar("survival_max_hunters"), 0);
		SetConVarInt(FindConVar("survival_max_smokers"), 0);
		SetConVarInt(FindConVar("survival_max_chargers"), 0);
		SetConVarInt(FindConVar("survival_max_spitters"), 0);
		SetConVarInt(FindConVar("survival_max_jockeys"), 0);	
		SetConVarInt(FindConVar("survival_max_specials"), SILimit);
		SetBossesCvar();
		SetConVarInt(FindConVar("director_spectate_specials"), 1);
	}
	else
	{
		ResetConVar(FindConVar("z_max_player_zombies"));
		ResetConVar(FindConVar("z_boomer_limit"));
		ResetConVar(FindConVar("z_hunter_limit"));
		ResetConVar(FindConVar("z_smoker_limit"));
		ResetConVar(FindConVar("z_charger_limit"));
		ResetConVar(FindConVar("z_spitter_limit"));
		ResetConVar(FindConVar("z_jockey_limit"));
		ResetConVar(FindConVar("survival_max_boomers"));
		ResetConVar(FindConVar("survival_max_hunters"));
		ResetConVar(FindConVar("survival_max_smokers"));
		ResetConVar(FindConVar("survival_max_chargers"));
		ResetConVar(FindConVar("survival_max_spitters"));
		ResetConVar(FindConVar("survival_max_jockeys"));
		ResetConVar(FindConVar("survival_max_specials"));
		ResetConVar(FindConVar("director_no_bosses"));	
		ResetConVar(FindConVar("director_spectate_specials"));
	}
	
	SetAIDelayCvars();
	SetAISpawnCvars();
}

SetBossesCvar() //both tank and witch must be handled by director or not
{
	if (WitchLimit < 0 || SpawnWeights[SI_TANK] < 0)
		SetConVarInt(FindConVar("director_no_bosses"), 0);
	else
		SetConVarInt(FindConVar("director_no_bosses"), 1);		
}

SetAIDelayCvars()
{
	FasterResponse = GetConVarBool(hFasterResponse);
	if (FasterResponse)
	{
		SetConVarInt(FindConVar("boomer_exposed_time_tolerance"), 0);			
		SetConVarInt(FindConVar("boomer_vomit_delay"), 0);
		SetConVarInt(FindConVar("smoker_tongue_delay"), 0);
		SetConVarInt(FindConVar("hunter_leap_away_give_up_range"), 0);
	}
	else
	{
		ResetConVar(FindConVar("boomer_exposed_time_tolerance"));
		ResetConVar(FindConVar("boomer_vomit_delay"));
		ResetConVar(FindConVar("smoker_tongue_delay"));
		ResetConVar(FindConVar("hunter_leap_away_give_up_range"));	
	}
}

SetAISpawnCvars()
{
	FasterSpawn = GetConVarBool(hFasterSpawn);
	if (FasterSpawn)
		SetConVarInt(FindConVar("z_spawn_safety_range"), 0);
	else
		ResetConVar(FindConVar("z_spawn_safety_range"));
}

//MI 5
GameModeCheck()
{
	//We determine what the gamemode is
	decl String:GameName[16];
	GetConVarString(FindConVar("mp_gamemode"), GameName, sizeof(GameName));
	if (StrContains(GameName, "survival", false) != -1)
		GameMode = 1; //3
	else if (StrContains(GameName, "versus", false) != -1)
		GameMode = 1; //2
	else if (StrContains(GameName, "coop", false) != -1)
		GameMode = 1; //1
	else 
		GameMode = 1; //0
}

public Action:SetConstantSpawnTime(client, args)
{
	ChangeByConstantTime = true; //prevent conflict with hooked event change
	if (args > 0)
	{
		new Float:time = 1.0;
		decl String:arg[8];
		GetCmdArg(1, arg, sizeof(arg));
		time = StringToFloat(arg);
		if (time < 0.0)
			time = 1.0;
		SetConVarFloat(hSpawnTimeMin, time);
		SetConVarFloat(hSpawnTimeMax, time);
		SetSpawnTimes(); //refresh times since hooked event from SetConVarFloat is temporarily disabled
		ReplyToCommand(client, "[AIS] Minimum and maximum spawn time set to %.3f seconds.", time);
	}
	else
		ReplyToCommand(client, "l4d2_ais_time <# of seconds>");
	ChangeByConstantTime = false;
}

SetSpawnTimes()
{
	SpawnTimeMin = GetConVarFloat(hSpawnTimeMin);
	SpawnTimeMax = GetConVarFloat(hSpawnTimeMax);	

	if (SpawnTimeOnPlayer == 1)
	{
		SpawnTimeMax = GetConVarFloat(hSpawnTimeMax) - AliveSurvivors * SpawnTimeReduceAmount;
	}

	if (SpawnTimeMin > SpawnTimeMax) //SpawnTimeMin cannot be greater than SpawnTimeMax
	{
		SetConVarFloat(hSpawnTimeMin, SpawnTimeMax); //set back to appropriate limit
	}
	else
	{
		if (SpawnTimeMax < SpawnTimeMin) //SpawnTimeMax cannot be less than SpawnTimeMin
		{
			SetConVarFloat(hSpawnTimeMax, SpawnTimeMin); //set back to appropriate limit
		}
		else
		{
			CalculateSpawnTimes(); //must recalculate spawn time table to compensate for min change
			if (LeftSafeRoom)
			{
				StartSpawnTimer(); //restart timer after times change
			}
		}
	}
	//Notify all players that current SI spawn interval
	CPrintToChatAll ("{green}[autoIS] {lightgreen}当前特感刷新间隔{olive}[%.2f, %.2f]{lightgreen}秒", SpawnTimeMin, SpawnTimeMax);
}

CalculateSpawnTimes()
{
	new i;
	if (SILimit > 1 && SpawnTimeMode > 0)
	{
		new Float:unit = (SpawnTimeMax-SpawnTimeMin)/(SILimit-1);
		switch (SpawnTimeMode)
		{
			case 1: //incremental spawn time mode
			{
				SpawnTimes[0] = SpawnTimeMin;
				for (i = 1; i <= MAX_INFECTED; i++)
				{
					if (i < SILimit)
						SpawnTimes[i] = SpawnTimes[i-1] + unit;
					else
						SpawnTimes[i] = SpawnTimeMax;
				}
			}
			case 2: //decremental spawn time mode
			{
				SpawnTimes[0] = SpawnTimeMax;
				for (i = 1; i <= MAX_INFECTED; i++)
				{
					if (i < SILimit)
						SpawnTimes[i] = SpawnTimes[i-1] - unit;
					else
						SpawnTimes[i] = SpawnTimeMax;
				}
			}
			//randomized spawn time mode does not use time tables
		}	
	}
	else //constant spawn time for if SILimit is 1
		SpawnTimes[0] = SpawnTimeMax;
	#if DEBUG_TIMES
	for (i = 0; i <= MAX_INFECTED; i++)
		LogMessage("[AIS] %d : %.5f s", i, SpawnTimes[i]);
	#endif
}

SetSpawnWeights()
{
	new i, weight, TotalWeight;
	//set and sum spawn weights
	for (i = 0; i < NUM_TYPES_INFECTED; i++)
	{
		weight = GetConVarInt(hSpawnWeights[i]);
		SpawnWeights[i] = weight;
		if (weight >= 0)
			TotalWeight += weight;
	}
	#if DEBUG_WEIGHTS
	for (i = 0; i < NUM_TYPES_INFECTED; i++)
		LogMessage("[AIS] %s weight: %d (%.5f)", Spawns[i], SpawnWeights[i]);
	#endif
}

public Action:PresetWeights(client, args)
{
	decl String:arg[16];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "default") == 0)
		ResetWeights();
	else if (strcmp(arg, "none") == 0)
		ZeroWeights();
	else //presets for spawning special infected i only
	{
		for (new i = 0; i < NUM_TYPES_INFECTED; i++)
		{
			if (strcmp(arg, Spawns[i]) == 0)
			{
				ZeroWeightsExcept(i);
				return Plugin_Handled;
			}
		}	
	}
	ReplyToCommand(client, "l4d2_ais_preset <default|none|smoker|boomer|hunter|spitter|jockey|charger|tank>");
	return Plugin_Handled;
}

ResetWeights()
{
	for (new i = 0; i < NUM_TYPES_INFECTED; i++)
		ResetConVar(hSpawnWeights[i]);
}
ZeroWeights()
{
	for (new i = 0; i < NUM_TYPES_INFECTED; i++)
		SetConVarInt(hSpawnWeights[i], 0);
}
ZeroWeightsExcept(index)
{
	for (new i = 0; i < NUM_TYPES_INFECTED; i++)
	{
		if (i == index)
			SetConVarInt(hSpawnWeights[i], 100);
		else
			SetConVarInt(hSpawnWeights[i], 0);
	}
	if (index != SI_TANK) //include director spawning of tank for non-tank SI presets
		ResetConVar(hSpawnWeights[SI_TANK]);
}

GenerateSpawn(client)
{
	CountSpecialInfected(); //refresh infected count
	if (SICount < SILimit) //spawn when infected count hasn't reached limit
	{
		new size;
		if (SpawnSize > SILimit - SICount) //prevent amount of special infected from exceeding SILimit
			size = SILimit - SICount;
		else
			size = SpawnSize;
		
		new index;
		new SpawnQueue[MAX_INFECTED] = {-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1};
		
		//refresh current SI counts
		SITypeCount();
		
		//generate the spawn queue
		for (new i = 0; i < size; i++)
		{
			index = GenerateIndex();
			if (index == -1)
				break;
			SpawnQueue[i]= index;
			SpawnCounts[index] += 1;
		}
		
		for (new i = 0; i < MAX_INFECTED; i++)
		{
			if(SpawnQueue[i] < 0) //stops if the current array index is out of bound
				break;
			new bot = CreateFakeClient("Infected Bot");
			if (bot != 0)
			{
				ChangeClientTeam(bot,TEAM_INFECTED);
				CreateTimer(0.1,kickbot,bot);
			}	
			CheatCommand(client, "z_spawn_old", Spawns[SpawnQueue[i]]); 
			
			#if DEBUG_SPAWNS
				LogMessage("[AIS] Spawned %s", Spawns[SpawnQueue[i]]);
			#endif
		}
	}
}

//MI
SITypeCount() //Count the number of each SI ingame
{
	for (new i = 0; i < NUM_TYPES_INFECTED; i++)
		SpawnCounts[i] = 0;

	for (new i = 1; i <= MaxClients; i++)
	{
		//If player is not connected ...
		if (!IsClientConnected(i)) continue;
		
		//We check if player is in game
		if (!IsClientInGame(i)) continue;
		
		//Check if client is infected ...
		if (GetClientTeam(i)==3)
		{
			switch (GetEntProp(i,Prop_Send,"m_zombieClass")) //detect SI type
			{
				case IS_SMOKER:
					SpawnCounts[SI_SMOKER]++;
				
				case IS_BOOMER:
					SpawnCounts[SI_BOOMER]++;
				
				case IS_HUNTER:
					SpawnCounts[SI_HUNTER]++;
				
				case IS_SPITTER:
					SpawnCounts[SI_SPITTER]++;
				
				case IS_JOCKEY:
					SpawnCounts[SI_JOCKEY]++;
				
				case IS_CHARGER:
					SpawnCounts[SI_CHARGER]++;
				
				case IS_TANK:
					SpawnCounts[SI_TANK]++;
			}
		}
	}
}

public Action:kickbot(Handle:timer, any:client)
{
	if (IsClientInGame(client) && (!IsClientInKickQueue(client)))
	{
		if (IsFakeClient(client)) KickClient(client);
	}
}

stock CheatCommand(client, String:command[], String:arguments[] = "")
{
	if (!client || !IsClientInGame(client))
	{
		for (new target = 1; target <= MaxClients; target++)
		{
			client = target;
			break;
		}
		
		return; // case no valid Client found
	}
	
	new userFlags = GetUserFlagBits(client);
	SetUserFlagBits(client, ADMFLAG_ROOT);
	new flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", command, arguments);
	SetCommandFlags(command, flags);
	SetUserFlagBits(client, userFlags);
}

GenerateIndex()
{
	new TotalSpawnWeight, StandardizedSpawnWeight;
	
	//temporary spawn weights factoring in SI spawn limits
	decl TempSpawnWeights[NUM_TYPES_INFECTED];
	for(new i = 0; i < NUM_TYPES_INFECTED; i++)
	{
		if(SpawnCounts[i] < SpawnLimits[i])
		{
			if(ScaleWeights)
				TempSpawnWeights[i] = (SpawnLimits[i] - SpawnCounts[i]) * SpawnWeights[i];
			else
				TempSpawnWeights[i] = SpawnWeights[i];
		}
		else
			TempSpawnWeights[i] = 0;
		
		TotalSpawnWeight += TempSpawnWeights[i];
	}
	
	//calculate end intervals for each spawn
	new Float:unit = 1.0/TotalSpawnWeight;
	for (new i = 0; i < NUM_TYPES_INFECTED; i++)
	{
		if (TempSpawnWeights[i] >= 0)
		{
			StandardizedSpawnWeight += TempSpawnWeights[i];
			IntervalEnds[i] = StandardizedSpawnWeight * unit;
		}
	}
	
	new Float:r = GetRandomFloat(0.0, 1.0); //selector r must be within the ith interval for i to be selected
	for (new i = 0; i < NUM_TYPES_INFECTED; i++)
	{
		//negative and 0 weights are ignored
		if (TempSpawnWeights[i] <= 0) continue;
		//r is not within the ith interval
		if (IntervalEnds[i] < r) continue;
		//selected index i because r is within ith interval
		return i;
	}
	return -1; //no selection because all weights were negative or 0
}

//special infected spawn timer based on time modes
StartSpawnTimer()
{
	//prevent multiple timer instances
	EndSpawnTimer();
	//only start spawn timer if plugin is enabled
	if (Enabled)
	{
		new Float:time;
		CountSpecialInfected();
		
		if (SpawnTimeMode > 0) //NOT randomization spawn time mode
			time = SpawnTimes[SICount]; //a spawn time based on the current amount of special infected
		else //randomization spawn time mode
			time = GetRandomFloat(SpawnTimeMin, SpawnTimeMax); //a random spawn time between min and max inclusive

		SpawnTimerStarted = true;
		hSpawnTimer = CreateTimer(time, SpawnInfectedAuto);
		#if DEBUG_TIMES
		LogMessage("[AIS] Mode: %d | SI: %d | Next: %.3f s", SpawnTimeMode, SICount, time);
		#endif
	}
}

//never directly set hSpawnTimer, use this function for custom spawn times
StartCustomSpawnTimer(Float:time)
{
	//prevent multiple timer instances
	EndSpawnTimer();
	//only start spawn timer if plugin is enabled
	if (Enabled)
	{
		SpawnTimerStarted = true;
		hSpawnTimer = CreateTimer(time, SpawnInfectedAuto);
	}
}
EndSpawnTimer()
{
	if (SpawnTimerStarted)
	{
		CloseHandle(hSpawnTimer);
		SpawnTimerStarted = false;
	}
}

StartWitchWaitTimer(Float:time)
{
	EndWitchWaitTimer();
	if (Enabled && WitchLimit > 0)
	{
		if (WitchCount < WitchLimit)
		{
			WitchWaitTimerStarted = true;
			hWitchWaitTimer = CreateTimer(time, StartWitchTimer);
			#if DEBUG_TIMES
			LogMessage("[AIS] Mode: %b | Witches: %d | Next(WitchWait): %.3f s", VariableWitchPeriod, WitchCount, time);
			#endif
		}
		else //if witch count reached limit, wait until a witch killed event to start witch timer
		{
			WitchCountFull = true;
			#if DEBUG_TIMES
			LogMessage("[AIS] Witch Limit reached. Waiting for witch death.");
			#endif		
		}
	}
}
public Action:StartWitchTimer(Handle:timer)
{
	WitchWaitTimerStarted = false;
	EndWitchTimer();
	if (Enabled && WitchLimit > 0)
	{
		new Float:time;
		if (VariableWitchPeriod)
			time = GetRandomFloat(0.0, WitchPeriod);
		else
			time = WitchPeriod;
		
		WitchTimerStarted = true;
		hWitchTimer = CreateTimer(time, SpawnWitchAuto, WitchPeriod-time);
		#if DEBUG_TIMES
		LogMessage("[AIS] Mode: %b | Witches: %d | Next(Witch): %.3f s", VariableWitchPeriod, WitchCount, time);
		#endif
	}
	return Plugin_Handled;
}
EndWitchWaitTimer()
{
	if (WitchWaitTimerStarted)
	{
		CloseHandle(hWitchWaitTimer);
		WitchWaitTimerStarted = false;
	}
}
EndWitchTimer()
{
	if (WitchTimerStarted)
	{
		CloseHandle(hWitchTimer);
		WitchTimerStarted = false;
	}
}
//take account of both witch timers when restarting overall witch timer
RestartWitchTimer(Float:time)
{
	EndWitchTimer();
	StartWitchWaitTimer(time);
}

StartTimers()
{
	StartSpawnTimer();
	RestartWitchTimer(0.0);
}
EndTimers()
{
	EndSpawnTimer();
	EndWitchWaitTimer();
	EndWitchTimer();
}

public Action:StartSpawnTimerManually(client, args)
{
	if (Enabled)
	{
		if (args < 1)
		{
			StartSpawnTimer();
			ReplyToCommand(client, "[AIS] Spawn timer started manually.");
		}
		else
		{
			new Float:time = 1.0;
			decl String:arg[8];
			GetCmdArg(1, arg, sizeof(arg));
			time = StringToFloat(arg);
			
			if (time < 0.0)
				time = 1.0;
			
			StartCustomSpawnTimer(time);
			ReplyToCommand(client, "[AIS] Spawn timer started manually. Next potential spawn in %.3f seconds.", time);
		}
	}
	else
		ReplyToCommand(client, "[AIS] Plugin is disabled. Enable plugin before manually starting timer.");

	return Plugin_Handled;
}
 
public Action:SpawnInfectedAuto(Handle:timer)
{
	SpawnTimerStarted = false; //spawn timer always stops here (the non-repeated spawn timer calls this function)
	if (LeftSafeRoom) //only spawn infected and repeat spawn timer when survivors have left safe room
	{
		new client = GetAnyClient();
		if (client) //make sure client is in-game
		{
			GenerateSpawn(client);
			StartSpawnTimer();
		}
		else //longer timer for when invalid client was returned (prevent a potential infinite loop when there are 0 SI)
			StartCustomSpawnTimer(SpawnTimeMax);
	}

	return Plugin_Handled;
}

public Action:SpawnWitchAuto(Handle:timer, any:waitTime)
{
	WitchTimerStarted = false;
	if (LeftSafeRoom)
	{
		new client = GetAnyClient();
		if (client)
		{
			if (WitchCount < WitchLimit)
				ExecuteCheatCommand(client, "z_spawn_old", "witch", "auto");
			StartWitchWaitTimer(waitTime);
		}
		else
			StartWitchWaitTimer(waitTime+1.0);
	}
	return Plugin_Handled;
}

ExecuteCheatCommand(client, const String:command[], String:param1[], String:param2[]) {
	//Hold original user flag for restoration, temporarily give user root admin flag (prevent conflict with admincheats)
	new admindata = GetUserFlagBits(client);
	SetUserFlagBits(client, ADMFLAG_ROOT);
	
	//Removes sv_cheat flag from command
	new flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);

	FakeClientCommand(client, "%s %s %s", command, param1, param2);
	
	//Restore command flag and user flag
	SetCommandFlags(command, flags);
	SetUserFlagBits(client, admindata);
}

public Action:aisDebug(client, args)
{	
	//Print the amount of alive player survivors , current SI spawn size and interval
	CPrintToChatAll ("{green}[autoIS] {lightgreen}DEBUG: 存活玩家数量为{olive}%i{lightgreen}, 特感数量改为{olive}%i{lightgreen}", AliveSurvivors, SpawnSize);
	CPrintToChatAll ("{green}[autoIS] {lightgreen}DEBUG: 当前特感刷新间隔{olive}[%.2f, %.2f]{lightgreen}秒", SpawnTimeMin, SpawnTimeMax);
}

public Action:ResetSpawns(client, args)
{	
	KillSpecialInfected();
	if (Enabled)
	{
		StartCustomSpawnTimer(SpawnTimes[0]);
		RestartWitchTimer(0.0);
		ReplyToCommand(client, "[AIS] Slayed all special infected. Spawn timer restarted. Next potential spawn in %.3f seconds.", SpawnTimeMin);
	}
	else
		ReplyToCommand(client, "[AIS] Slayed all special infected.");
	return Plugin_Handled;
}

CountSpecialInfected()
{
	//reset counter
	SICount = 0;
	
	//First we count the amount of infected players
	for (new i = 1; i <= MaxClients; i++)
	{
		//If player is not connected ...
		if (!IsClientConnected(i)) continue;
		
		//We check if player is in game
		if (!IsClientInGame(i)) continue;
		
		//Check if client is infected ...
		if (GetClientTeam(i)==3)
			SICount++;
	}
}

KillSpecialInfected()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsClientConnected(i)) continue;
		
		if (!IsClientInGame(i)) continue;
		
		if (GetClientTeam(i)==3)
			ForcePlayerSuicide(i);
	}
	
	//reset counter after all special infected have been killed
	SICount = 0;
}

public GetAnyClient ()
{
	for (new  i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && IsClientInGame(i) && (!IsFakeClient(i)))
			return i;
	}
	return 0;
}

//MI 5
public Action:evtRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{	
	//If round haven't started
	if (!RoundStarted)
	{
		//and we reset some variables
		RoundEnded = false;
		RoundStarted = true;
		LeftSafeRoom = SafeSpawn; //depends on whether special infected should spawn while survivors are in starting safe room
		WitchCount = 0;
		SpawnTimerStarted = false;
		WitchTimerStarted = false;
		WitchWaitTimerStarted = false;
		WitchCountFull = false;

		SurvivorCheck();
		//Print the amount of alive player survivors , current SI spawn size and interval
		CPrintToChatAll ("{green}[autoIS] {lightgreen}初始化, 存活玩家数量为{olive}%i{lightgreen}, 特感数量改为{olive}%i{lightgreen}", AliveSurvivors, SpawnSize);
		CPrintToChatAll ("{green}[autoIS] {lightgreen}当前特感刷新间隔{olive}[%.2f, %.2f]{lightgreen}秒", SpawnTimeMin, SpawnTimeMax);
		InitTimers();
	}
}

//MI 5
public Action:evtRoundEnd (Handle:event, const String:name[], bool:dontBroadcast)
{	
	//If round has not been reported as ended ..
	if (!RoundEnded)
	{
		//we mark the round as ended
		EndTimers();
		RoundEnded = true;
		RoundStarted = false;
		LeftSafeRoom = false;
	}
}

public evtPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	SurvivorCheck();
}

public evtTankSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	CheckHaveTank();
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!SpawnSIWithTank)
	{
		if(HaveTank && IsTank(client, ZOMBIECLASS_TANK))
		{
			EndTimers();
			//Notify all players that tank spawns
			CPrintToChatAll("{green}[autoIS] {lightgreen}Tank出现, 暂停特感生成");
		}
	}
}

public evtPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	SurvivorCheck();
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(IsValidClient(client))
	{
		if(SpawnSizeOnPlayer == 1)
		{
			//Notify all players that someone dead and current amount of alive player survivors
			CPrintToChatAll ("{green}[autoIS] {lightgreen}玩家死亡, 存活玩家数量为{olive}%i{lightgreen}, 特感数量改为{olive}%i{lightgreen}", AliveSurvivors, SpawnSize);
		}
		if(SpawnTimeOnPlayer == 1)
		{
			////Notify all players that current SI spawn interval
			CPrintToChatAll ("{green}[autoIS] {lightgreen}当前特感刷新间隔{olive}[%.2f, %.2f]{lightgreen}秒", SpawnTimeMin, SpawnTimeMax);
		}
	}

	//If Tank die
	CheckHaveTank();
	if(!SpawnSIWithTank)
	{
		if(!HaveTank && IsTank(client, ZOMBIECLASS_TANK))
		{
			StartTimers();
			//Notify all players that all tanks dead and restart SI spawn timers
			CPrintToChatAll("{green}[autoIS] {lightgreen}全部Tank死亡, 恢复特感生成");
		}
	}
}

public evtSurvivorRescued(Handle:event, const String:name[], bool:dontBroadcast)
{
	SurvivorCheck();
	new client = GetClientOfUserId(GetEventInt(event, "victim"));
	if(IsValidClient(client))
	{
		if(SpawnSizeOnPlayer == 1)
		{
			//Notify all players that someone being rescued and current amount of alive player survivors and SI spawn size
			CPrintToChatAll ("{green}[autoIS] {lightgreen}玩家获救, 存活玩家数量为{olive}%i{lightgreen}, 特感数量改为{olive}%i{lightgreen}", AliveSurvivors, SpawnSize);
		}
		if(SpawnTimeOnPlayer == 1)
		{
			//Notify all players that current SI spawn interval
			CPrintToChatAll ("{green}[autoIS] {lightgreen}当前特感刷新间隔{olive}[%.2f, %.2f]{lightgreen}秒", SpawnTimeMin, SpawnTimeMax);
		}
	}
}

public evtPlayerTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	SurvivorCheck();
}



//MI 5
public Action:PlayerLeftStart(Handle:Timer)
{
	if (LeftStartArea())
	{
		// We don't care who left, just that at least one did
		if (!LeftSafeRoom)
		{
			LeftSafeRoom = true;
			StartTimers();		
		}
		SafeRoomChecking = false;
	}
	else
		CreateTimer(1.0, PlayerLeftStart);
	
	return Plugin_Continue;
}

//MI 5
bool:LeftStartArea()
{
	new ent = -1, maxents = GetMaxEntities();
	for (new i = MaxClients+1; i <= maxents; i++)
	{
		if (IsValidEntity(i))
		{
			decl String:netclass[64];
			GetEntityNetClass(i, netclass, sizeof(netclass));
			
			if (StrEqual(netclass, "CTerrorPlayerResource"))
			{
				ent = i;
				break;
			}
		}
	}
	
	if (ent > -1)
	{
		new offset = FindSendPropInfo("CTerrorPlayerResource", "m_hasAnySurvivorLeftSafeArea");
		if (offset > 0)
		{
			if (GetEntData(ent, offset))
			{
				if (GetEntData(ent, offset) == 1) return true;
			}
		}
	}
	return false;
}

//MI 5
//This is hooked to the panic event, but only starts if its survival. This is what starts up the bots in survival.
public Action:evtSurvivalStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (GameMode == 3)
	{  
		if (!LeftSafeRoom)
		{
			LeftSafeRoom = true;
			StartTimers();
		}
	}
	return Plugin_Continue;
}

//Kick infected bots immediately after they die to allow quicker infected respawn
public Action:evtInfectedDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (FasterSpawn)
	{
		new client = GetClientOfUserId(GetEventInt(event, "userid"));
		
		if (client) {
			if (GetClientTeam(client) == 3 && IsFakeClient(client))
				KickClient(client, "");
		}
	}
}

public Action:evtWitchSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	WitchCount++;
}

/*
public Action:evtWitchHarasse(Handle:event, const String:name[], bool:dontBroadcast)
{
	decl String:names[32];
	new killer = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (GetClientTeam(killer) == 2) //only show message if player is in survivor team
	{
		GetClientName(killer, names, sizeof(names));
		PrintToChatAll("%s startled the Witch!",names);
	}
}
*/
public Action:evtWitchKilled(Handle:event, const String:name[], bool:dontBroadcast)
{
	WitchCount--;
	if (WitchCountFull)
	{
		WitchCountFull = false;
		StartWitchWaitTimer(0.0);
	}
}

SurvivorCheck()
{
	if (GetConVarInt(hEnabled) == 1)
	{
		//PrintToServer("SurvivorCheck");
		new alivesurvivors = 0;
		new survivors = 0;
		for (new i = 1; i <= MaxClients; i++)
		{
			if(i)
			{
				if (IsClientConnected(i) && IsClientInGame(i) && GetClientTeam(i) == 2 && !IsFakeClient(i))
				{
					survivors++;
					if (IsPlayerAlive(i))
					{
						alivesurvivors++;
					}
				}
			}
		}

		AliveSurvivors = alivesurvivors;
		SetSpawnSizeOnPlayer();
		SetSpawnTimeOnPlayer();
	}
}

SetSpawnSizeOnPlayer()
{
	if (SpawnSizeOnPlayer == 1)
	{
		SpawnSize = GetConVarInt(hSpawnSize) + SpawnSizeAddAmount * AliveSurvivors; 
	}
	else
	{
		SpawnSize = GetConVarInt(hSpawnSize); 
	}
}

SetSpawnTimeOnPlayer()
{	
	if (SpawnTimeOnPlayer == 1)
	{
		SpawnTimeMax = GetConVarFloat(hSpawnTimeMax) - AliveSurvivors * SpawnTimeReduceAmount;
	}

	if (SpawnTimeMin > SpawnTimeMax) //SpawnTimeMin cannot be greater than SpawnTimeMax
	{
		SetConVarFloat(hSpawnTimeMin, SpawnTimeMax); //set back to appropriate limit
	}
	else
	{
		if (SpawnTimeMax < SpawnTimeMin) //SpawnTimeMax cannot be less than SpawnTimeMin
		{
			SetConVarFloat(hSpawnTimeMax, SpawnTimeMin); //set back to appropriate limit
		}
		else
		{
			CalculateSpawnTimes(); //must recalculate spawn time table to compensate for min change
		}
	}
}

CheckHaveTank()
{
	HaveTank = false;
	for( int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i) && IsTank(i, ZOMBIECLASS_TANK))
		{
			HaveTank = true;
		}
	}
}

bool IsTank(int client, int type)
{
	if( client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3)
	{
		int class = GetEntProp(client, Prop_Send, "m_zombieClass");
		if(class == type) return true;
		else return false;
	}
	else return false;
}

bool IsValidClient(int client)
{
	if(client <= 0 || client > MaxClients || !IsClientConnected(client) || !IsClientInGame(client) || IsFakeClient(client)) return false;
	else return true;
}

public OnMapEnd()
{
	RoundStarted = false;
	RoundEnded = true;
	LeftSafeRoom = false;
	//KillTimer(timer);
}