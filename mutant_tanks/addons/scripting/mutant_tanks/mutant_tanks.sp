/**
 * Mutant Tanks: a L4D/L4D2 SourceMod Plugin
 * Copyright (C) 2022  Alfred "Psyk0tik" Llagas
 *
 * This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
 **/

#include <sourcemod>
#include <dhooks>
#include <mutant_tanks>

#undef REQUIRE_EXTENSIONS
#tryinclude <clientprefs>
#define REQUIRE_EXTENSIONS

#undef REQUIRE_PLUGIN
#tryinclude <adminmenu>
#tryinclude <autoexecconfig>
#tryinclude <mt_clone>
#tryinclude <ThirdPersonShoulder_Detect>
#tryinclude <updater>
#tryinclude <WeaponHandling>
#define REQUIRE_PLUGIN

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name = MT_NAME,
	author = MT_AUTHOR,
	description = MT_DESCRIPTION,
	version = MT_VERSION,
	url = MT_URL
};

bool g_bDedicated, g_bLateLoad, g_bSecondGame;

Handle g_hPluginHandle;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	switch (GetEngineVersion())
	{
		case Engine_Left4Dead: g_bSecondGame = false;
		case Engine_Left4Dead2: g_bSecondGame = true;
		default:
		{
			strcopy(error, err_max, "\"Mutant Tanks\" only supports Left 4 Dead 1 & 2");

			return APLRes_SilentFailure;
		}
	}

	if (GetFeatureStatus(FeatureType_Native, "MT_IsTypeEnabled") != FeatureStatus_Unknown)
	{
		strcopy(error, err_max, "\"Mutant Tanks\" is already running. Please remove the duplicate plugin");

		return APLRes_SilentFailure;
	}

	if (GetFeatureStatus(FeatureType_Native, "ST_IsTypeEnabled") != FeatureStatus_Unknown)
	{
		strcopy(error, err_max, "\"Super Tanks++\" is already running. Please remove the duplicate plugin");

		return APLRes_SilentFailure;
	}

	RegPluginLibrary("mutant_tanks");
	vRegisterForwards();
	vRegisterNatives();

	g_bDedicated = IsDedicatedServer();
	g_bLateLoad = late;
	g_hPluginHandle = myself;

	return APLRes_Success;
}

#define MODEL_CONCRETE_CHUNK "models/props_debris/concrete_chunk01a.mdl"
#define MODEL_FIREWORKCRATE "models/props_junk/explosive_box001.mdl" // Only available in L4D2
#define MODEL_GASCAN "models/props_junk/gascan001a.mdl"
#define MODEL_OXYGENTANK "models/props_equipment/oxygentank01.mdl"
#define MODEL_PROPANETANK "models/props_junk/propanecanister001a.mdl"
#define MODEL_TANK_MAIN "models/infected/hulk.mdl"
#define MODEL_TANK_DLC "models/infected/hulk_dlc3.mdl"
#define MODEL_TANK_L4D1 "models/infected/hulk_l4d1.mdl" // Only available in L4D2
#define MODEL_TIRES "models/props_vehicles/tire001c_car.mdl"
#define MODEL_TREE_TRUNK "models/props_foliage/tree_trunk.mdl"
#define MODEL_WITCH "models/infected/witch.mdl"
#define MODEL_WITCHBRIDE "models/infected/witch_bride.mdl" // Only available in L4D2

#define PARTICLE_ACHIEVED "achieved"
#define PARTICLE_BLOOD "boomer_explode_D"
#define PARTICLE_ELECTRICITY "electrical_arc_01_system"
#define PARTICLE_FIRE "aircraft_destroy_fastFireTrail"
#define PARTICLE_FIREWORK "mini_fireworks"
#define PARTICLE_GORE "gore_wound_fullbody_1"
#define PARTICLE_ICE "apc_wheel_smoke1"
#define PARTICLE_METEOR "smoke_medium_01"
#define PARTICLE_SMOKE "smoker_smokecloud"
#define PARTICLE_SPIT "spitter_projectile" // Only available in L4D2
#define PARTICLE_SPIT2 "spitter_slime_trail" // Only available in L4D2

#define SOUND_ACHIEVEMENT "ui/pickup_misc42.wav"
#define SOUND_DAMAGE "player/damage1.wav"
#define SOUND_DAMAGE2 "player/damage2.wav"
#define SOUND_DEATH "ui/pickup_scifi37.wav"
#define SOUND_ELECTRICITY "items/suitchargeok1.wav"
#define SOUND_EXPLOSION2 "weapons/grenade_launcher/grenadefire/grenade_launcher_explode_2.wav" // Only available in L4D2
#define SOUND_EXPLOSION1 "animation/van_inside_debris.wav" // Only used in L4D1
#define SOUND_LADYKILLER "ui/alert_clink.wav"
#define SOUND_METAL "physics/metal/metal_solid_impact_hard5.wav"
#define SOUND_NULL "common/null.wav"
#define SOUND_SPAWN "ui/pickup_secret01.wav"
#define SOUND_SPIT "player/spitter/voice/warn/spitter_spit_02.wav" // Only available in L4D2
#define SOUND_THROWN "player/tank/attack/thrown_missile_loop_1.wav"

#define SPRITE_EXPLODE "sprites/zerogxplode.spr"
#define SPRITE_GLOW "sprites/glow01.vmt"
#define SPRITE_LASER "sprites/laser.vmt"
#define SPRITE_LASERBEAM "sprites/laserbeam.vmt"

#define MT_ACT_TERROR_HIT_BY_TANKPUNCH 1077 // ACT_TERROR_HIT_BY_TANKPUNCH
#define MT_ACT_TERROR_HULK_VICTORY 792 // ACT_TERROR_HULK_VICTORY
#define MT_ACT_TERROR_RAGE_AT_KNOCKDOWN 795 // ACT_TERROR_RAGE_AT_KNOCKDOWN
#define MT_ACT_TERROR_IDLE_FALL_FROM_TANKPUNCH 1078 // ACT_TERROR_IDLE_FALL_FROM_TANKPUNCH
#define MT_ACT_TERROR_POUNCED_TO_STAND 1263 // ACT_TERROR_POUNCED_TO_STAND
#define MT_ACT_TERROR_TANKPUNCH_LAND 1079 // ACT_TERROR_TANKPUNCH_LAND
#define MT_ACT_TERROR_TANKROCK_TO_STAND 1283 // ACT_TERROR_TANKROCK_TO_STAND

#define MT_ANIM_ACTIVESTATE 65 // active/standing state
#define MT_ANIM_LANDING 96 // landing on something
#define MT_ANIM_TANKPUNCHED 57 // punched by a Tank

#define MT_ARRIVAL_SPAWN (1 << 0) // announce spawn
#define MT_ARRIVAL_BOSS (1 << 1) // announce evolution
#define MT_ARRIVAL_RANDOM (1 << 2) // announce randomization
#define MT_ARRIVAL_TRANSFORM (1 << 3) // announce transformation
#define MT_ARRIVAL_REVERT (1 << 4) // announce revert

#define MT_CMD_SPAWN (1 << 0) // "sm_tank"/"sm_mt_tank"
#define MT_CMD_CONFIG (1 << 1) // "sm_mt_config"
#define MT_CMD_LIST (1 << 2) // "sm_mt_list"
#define MT_CMD_RELOAD (1 << 3) // "sm_mt_reload"
#define MT_CMD_VERSION (1 << 4) // "sm_mt_version"

#define MT_CONFIG_DIFFICULTY (1 << 0) // difficulty_configs
#define MT_CONFIG_MAP (1 << 1) // l4d_map_configs/l4d2_map_configs
#define MT_CONFIG_GAMEMODE (1 << 2) // l4d_gamemode_configs/l4d2_gamemode_configs
#define MT_CONFIG_DAY (1 << 3) // daily_configs
#define MT_CONFIG_PLAYERCOUNT (1 << 4) // playercount_configs
#define MT_CONFIG_SURVIVORCOUNT (1 << 5) // survivorcount_configs
#define MT_CONFIG_INFECTEDCOUNT (1 << 6) // infectedcount_configs
#define MT_CONFIG_FINALE (1 << 7) // l4d_finale_configs/l4d2_finale_configs

#define MT_CONFIG_FILE_MAIN "mutant_tanks.cfg"
#define MT_CONFIG_FILE_DETOURS "mutant_tanks_detours"
#define MT_CONFIG_FILE_PATCHES "mutant_tanks_patches"
#define MT_CONFIG_FILE_SIGNATURES "mutant_tanks_signatures"
#define MT_CONFIG_FILEPATH "data/mutant_tanks/"
#define MT_CONFIG_PATH_DAY "daily_configs/"
#define MT_CONFIG_PATH_DIFFICULTY "difficulty_configs/"
#define MT_CONFIG_PATH_FINALE "l4d_finale_configs/"
#define MT_CONFIG_PATH_FINALE2 "l4d2_finale_configs/"
#define MT_CONFIG_PATH_GAMEMODE "l4d_gamemode_configs/"
#define MT_CONFIG_PATH_GAMEMODE2 "l4d2_gamemode_configs/"
#define MT_CONFIG_PATH_INFECTEDCOUNT "infectedcount_configs/"
#define MT_CONFIG_PATH_MAP "l4d_map_configs/"
#define MT_CONFIG_PATH_MAP2 "l4d2_map_configs/"
#define MT_CONFIG_PATH_PLAYERCOUNT "playercount_configs/"
#define MT_CONFIG_PATH_SURVIVORCOUNT "survivorcount_configs/"

#define MT_CONFIG_SECTION_MAIN "Mutant Tanks"
#define MT_CONFIG_SECTION_MAIN2 "MutantTanks"
#define MT_CONFIG_SECTION_MAIN3 "Mutant_Tanks"
#define MT_CONFIG_SECTION_MAIN4 "MTanks"
#define MT_CONFIG_SECTION_MAIN5 "MT"
#define MT_CONFIG_SECTION_SETTINGS "PluginSettings"
#define MT_CONFIG_SECTION_SETTINGS2 "Plugin Settings"
#define MT_CONFIG_SECTION_SETTINGS3 "Plugin_Settings"
#define MT_CONFIG_SECTION_SETTINGS4 "settings"
#define MT_CONFIG_SECTION_GENERAL "General"
#define MT_CONFIG_SECTION_ANNOUNCE "Announcements"
#define MT_CONFIG_SECTION_ANNOUNCE2 "announce"
#define MT_CONFIG_SECTION_COLORS "Colors"
#define MT_CONFIG_SECTION_REWARDS "Rewards"
#define MT_CONFIG_SECTION_COMP "Competitive"
#define MT_CONFIG_SECTION_COMP2 "comp"
#define MT_CONFIG_SECTION_DIFF "Difficulty"
#define MT_CONFIG_SECTION_DIFF2 "diff"
#define MT_CONFIG_SECTION_HEALTH "Health"
#define MT_CONFIG_SECTION_HUMAN "HumanSupport"
#define MT_CONFIG_SECTION_HUMAN2 "Human Support"
#define MT_CONFIG_SECTION_HUMAN3 "Human_Support"
#define MT_CONFIG_SECTION_HUMAN4 "human"
#define MT_CONFIG_SECTION_WAVES "Waves"
#define MT_CONFIG_SECTION_CONVARS "ConVars"
#define MT_CONFIG_SECTION_CONVARS2 "cvars"
#define MT_CONFIG_SECTION_GAMEMODES "GameModes"
#define MT_CONFIG_SECTION_GAMEMODES2 "Game Modes"
#define MT_CONFIG_SECTION_GAMEMODES3 "Game_Modes"
#define MT_CONFIG_SECTION_GAMEMODES4 "modes"
#define MT_CONFIG_SECTION_CUSTOM "Custom"
#define MT_CONFIG_SECTION_GLOW "Glow"
#define MT_CONFIG_SECTION_SPAWN "Spawn"
#define MT_CONFIG_SECTION_BOSS "Boss"
#define MT_CONFIG_SECTION_COMBO "Combo"
#define MT_CONFIG_SECTION_RANDOM "Random"
#define MT_CONFIG_SECTION_TRANSFORM "Transform"
#define MT_CONFIG_SECTION_ADMIN "Administration"
#define MT_CONFIG_SECTION_ADMIN2 "admin"
#define MT_CONFIG_SECTION_PROPS "Props"
#define MT_CONFIG_SECTION_PARTICLES "Particles"
#define MT_CONFIG_SECTION_ENHANCE "Enhancements"
#define MT_CONFIG_SECTION_ENHANCE2 "enhance"
#define MT_CONFIG_SECTION_IMMUNE "Immunities"
#define MT_CONFIG_SECTION_IMMUNE2 "immune"

#define MT_DATA_SECTION_GAME_BOTH "Both"
#define MT_DATA_SECTION_GAME "Left4Dead"
#define MT_DATA_SECTION_GAME2 "Left 4 Dead"
#define MT_DATA_SECTION_GAME3 "Left_4_Dead"
#define MT_DATA_SECTION_GAME4 "L4D"
#define MT_DATA_SECTION_GAME_ONE "Left4Dead1"
#define MT_DATA_SECTION_GAME_ONE2 "Left 4 Dead 1"
#define MT_DATA_SECTION_GAME_ONE3 "Left_4_Dead_1"
#define MT_DATA_SECTION_GAME_ONE4 "L4D1"
#define MT_DATA_SECTION_GAME_TWO "Left4Dead2"
#define MT_DATA_SECTION_GAME_TWO2 "Left 4 Dead 2"
#define MT_DATA_SECTION_GAME_TWO3 "Left_4_Dead_2"
#define MT_DATA_SECTION_GAME_TWO4 "L4D2"

#define MT_DATA_SECTION_OS "Linux"
#define MT_DATA_SECTION_OS2 "Lin"
#define MT_DATA_SECTION_OS3 "Macintosh"
#define MT_DATA_SECTION_OS4 "Mac"
#define MT_DATA_SECTION_OS5 "Windows"
#define MT_DATA_SECTION_OS6 "Win"

#define MT_DETOUR_LIMIT 100 // number of detours allowed

#define MT_DETOURS_SECTION_MAIN "Mutant Tanks Detours"
#define MT_DETOURS_SECTION_MAIN2 "MutantTanksDetours"
#define MT_DETOURS_SECTION_MAIN3 "Mutant_Tanks_Detours"
#define MT_DETOURS_SECTION_MAIN4 "MTDetours"
#define MT_DETOURS_SECTION_MAIN5 "Detours"
#define MT_DETOURS_SECTION_PREFIX "MTDetour_"

#define MT_DEV_MAXLEVEL 4095

#define MT_EFFECT_TROPHY (1 << 0) // trophy
#define MT_EFFECT_FIREWORKS (1 << 1) // fireworks particles
#define MT_EFFECT_SOUND (1 << 2) // sound effect
#define MT_EFFECT_THIRDPERSON (1 << 3) // thirdperson view

#define MT_GAMEDATA "mutant_tanks"
#define MT_GAMEDATA_TEMP "mutant_tanks_temp"

#define MT_INFAMMO_PRIMARY (1 << 0) // primary weapon
#define MT_INFAMMO_SECONDARY (1 << 1) // secondary weapon
#define MT_INFAMMO_THROWABLE (1 << 2) // throwable
#define MT_INFAMMO_MEDKIT (1 << 3) // medkit
#define MT_INFAMMO_PILLS (1 << 4) // pills

#define MT_JUMP_DASHCOOLDOWN 0.15 // time between air dashes
#define MT_JUMP_DEFAULTHEIGHT 57.0 // default jump height
#define MT_JUMP_FALLPASSES 3 // safe fall passes
#define MT_JUMP_FORWARDBOOST 50.0 // forward boost for each jump

#define MT_L4D1_AMMOTYPE_PISTOL 1 // pistol
#define MT_L4D1_AMMOTYPE_HUNTING_RIFLE 2 // hunting_rifle
#define MT_L4D1_AMMOTYPE_RIFLE 3 // rifle
#define MT_L4D1_AMMOTYPE_SMG 5 // smg
#define MT_L4D1_AMMOTYPE_SHOTGUN 6 // pumpshotgun/autoshotgun

#define MT_L4D2_AMMOTYPE_PISTOL 1 // pistol
#define MT_L4D2_AMMOTYPE_PISTOL_MAGNUM 2 // pistol_magnum
#define MT_L4D2_AMMOTYPE_RIFLE 3 // rifle/rifle_ak47/rifle_desert/rifle_sg552
#define MT_L4D2_AMMOTYPE_SMG 5 // smg/smg_silenced/smg_mp5
#define MT_L4D2_AMMOTYPE_RIFLE_M60 6 // rifle_m60
#define MT_L4D2_AMMOTYPE_SHOTGUN_TIER1 7 // pumpshotgun/shotgun_chrome
#define MT_L4D2_AMMOTYPE_SHOTGUN_TIER2 8 // autoshotgun/shotgun_spas
#define MT_L4D2_AMMOTYPE_HUNTING_RIFLE 9 // hunting_rifle
#define MT_L4D2_AMMOTYPE_SNIPER_RIFLE 10 // sniper_military/sniper_awp/sniper_scout
#define MT_L4D2_AMMOTYPE_GRENADE_LAUNCHER 17 // grenade_launcher

#define MT_PARTICLE_BLOOD (1 << 0) // blood particle
#define MT_PARTICLE_ELECTRICITY (1 << 1) // electric particle
#define MT_PARTICLE_FIRE (1 << 2) // fire particle
#define MT_PARTICLE_ICE (1 << 3) // ice particle
#define MT_PARTICLE_METEOR (1 << 4) // meteor particle
#define MT_PARTICLE_SMOKE (1 << 5) // smoke particle
#define MT_PARTICLE_SPIT (1 << 6) // spit particle

#define MT_PATCH_LIMIT 100 // number of patches allowed
#define MT_PATCH_MAXLEN 48 // number of bytes allowed

#define MT_PATCHES_SECTION_MAIN "Mutant Tanks Patches"
#define MT_PATCHES_SECTION_MAIN2 "MutantTanksPatches"
#define MT_PATCHES_SECTION_MAIN3 "Mutant_Tanks_Patches"
#define MT_PATCHES_SECTION_MAIN4 "MTPatches"
#define MT_PATCHES_SECTION_MAIN5 "Patches"
#define MT_PATCHES_SECTION_PREFIX "MTPatch_"

#define MT_PROP_BLUR (1 << 0) // blur prop
#define MT_PROP_LIGHT (1 << 1) // light prop
#define MT_PROP_OXYGENTANK (1 << 2) // oxgyen tank prop
#define MT_PROP_FLAME (1 << 3) // flame prop
#define MT_PROP_ROCK (1 << 4) // rock prop
#define MT_PROP_TIRE (1 << 5) // tire prop
#define MT_PROP_PROPANETANK (1 << 6) // propane tank prop
#define MT_PROP_FLASHLIGHT (1 << 7) // flashlight prop
#define MT_PROP_CROWN (1 << 8) // crown prop

#define MT_ROCK_BLOOD (1 << 0) // blood particle
#define MT_ROCK_ELECTRICITY (1 << 1) // electric particle
#define MT_ROCK_FIRE (1 << 2) // fire particle
#define MT_ROCK_SPIT (1 << 3) // spit particle

#define MT_SIGNATURE_LIMIT 100 // number of signatures allowed

#define MT_SIGNATURES_SECTION_MAIN "Mutant Tanks Signatures"
#define MT_SIGNATURES_SECTION_MAIN2 "MutantTanksSignatures"
#define MT_SIGNATURES_SECTION_MAIN3 "Mutant_Tanks_Signatures"
#define MT_SIGNATURES_SECTION_MAIN4 "MTSignatures"
#define MT_SIGNATURES_SECTION_MAIN5 "Signatures"
#define MT_SIGNATURES_SECTION_PREFIX "MTSignature_"

#define MT_UPDATE_URL "https://raw.githubusercontent.com/Psykotikism/Mutant_Tanks/master/addons/sourcemod/mutant_tanks_updater.txt"

#define MT_USEFUL_REFILL (1 << 0) // useful refill reward
#define MT_USEFUL_HEALTH (1 << 1) // useful health reward
#define MT_USEFUL_AMMO (1 << 2) // useful ammo reward
#define MT_USEFUL_RESPAWN (1 << 3) // useful respawn reward

#define MT_VISUAL_SCREEN (1 << 0) // screen color
#define MT_VISUAL_PARTICLE (1 << 1) // particle effect
#define MT_VISUAL_VOICELINE (1 << 2) // looping voiceline
#define MT_VISUAL_VOICEPITCH (1 << 3) // voice pitch
#define MT_VISUAL_LIGHT (1 << 4) // flashlight
#define MT_VISUAL_BODY (1 << 5) // body color
#define MT_VISUAL_GLOW (1 << 6) // glow outline

#define MT_WATER_NONE 0 // not in water
#define MT_WATER_FEET 1 // feet in water
#define MT_WATER_WAIST 2 // waist in water
#define MT_WATER_HEAD 3 // head in water

enum ConfigState
{
	ConfigState_None, // no section yet
	ConfigState_Start, // reached "Mutant Tanks" section
	ConfigState_Settings, // reached "Plugin Settings" section
	ConfigState_Type, // reached "Tank #" section
	ConfigState_Admin, // reached "STEAM_"/"[U:" section
	ConfigState_Specific // reached specific sections
};

enum DataState
{
	DataState_None, // no section yet
	DataState_Start, // reached "Detours"/"Patches" section
	DataState_Game, // reached "left4dead"/"left4dead2"/"both" section
	DataState_Name, // reached "MTDetour_FunctionName"/"MTPatch_PatchName" section
	DataState_OS, // reached "linux"/"windows" section
};

enum struct esGeneral
{
	Address g_adDirector;
	Address g_adDoJumpValue;
	Address g_adOriginalJumpHeight[2];
	Address g_adOriginalVerticalPunch;

	ArrayList g_alAbilitySections[4];
	ArrayList g_alColorKeys[2];
	ArrayList g_alCompTypes;
	ArrayList g_alFilePaths;
	ArrayList g_alPlugins;
	ArrayList g_alSections;
#if defined _mtclone_included
	bool g_bCloneInstalled;
#endif
	bool g_bAbilityPlugin[MT_MAXABILITIES + 1];
	bool g_bFinaleEnded;
	bool g_bFinalMap;
	bool g_bForceSpawned;
	bool g_bHideNameChange;
	bool g_bNextRound;
	bool g_bNormalMap;
	bool g_bOverrideDetour;
	bool g_bOverridePatch;
	bool g_bPatchFallingSound;
	bool g_bPatchJumpHeight;
	bool g_bPatchVerticalPunch;
	bool g_bPluginEnabled;
	bool g_bSameMission;
	bool g_bUpdateDoJumpMemAccess;
	bool g_bUpdateWeaponInfoMemAccess;
	bool g_bUsedParser;
	bool g_bWitchKilled[2048];

	char g_sBodyColorVisual[64];
	char g_sBodyColorVisual2[64];
	char g_sBodyColorVisual3[64];
	char g_sBodyColorVisual4[64];
	char g_sChosenPath[PLATFORM_MAX_PATH];
	char g_sCurrentMissionDisplayTitle[64];
	char g_sCurrentMissionName[64];
	char g_sCurrentSection[128];
	char g_sCurrentSection2[128];
	char g_sCurrentSection3[128];
	char g_sCurrentSection4[128];
	char g_sCurrentSubSection[128];
	char g_sCurrentSubSection2[128];
	char g_sCurrentSubSection3[128];
	char g_sDefaultGunVerticalPunch[6];
	char g_sDisabledGameModes[513];
	char g_sEnabledGameModes[513];
	char g_sFallVoicelineReward[64];
	char g_sFallVoicelineReward2[64];
	char g_sFallVoicelineReward3[64];
	char g_sFallVoicelineReward4[64];
	char g_sHealthCharacters[4];
	char g_sItemReward[320];
	char g_sItemReward2[320];
	char g_sItemReward3[320];
	char g_sItemReward4[320];
	char g_sLightColorVisual[64];
	char g_sLightColorVisual2[64];
	char g_sLightColorVisual3[64];
	char g_sLightColorVisual4[64];
	char g_sLogFile[PLATFORM_MAX_PATH];
	char g_sLoopingVoicelineVisual[64];
	char g_sLoopingVoicelineVisual2[64];
	char g_sLoopingVoicelineVisual3[64];
	char g_sLoopingVoicelineVisual4[64];
	char g_sOutlineColorVisual[64];
	char g_sOutlineColorVisual2[64];
	char g_sOutlineColorVisual3[64];
	char g_sOutlineColorVisual4[64];
	char g_sSavePath[PLATFORM_MAX_PATH];
	char g_sScreenColorVisual[64];
	char g_sScreenColorVisual2[64];
	char g_sScreenColorVisual3[64];
	char g_sScreenColorVisual4[64];
	char g_sSection[PLATFORM_MAX_PATH];

	ConfigState g_csState;
	ConfigState g_csState2;

	ConVar g_cvMTAmmoPackUseDuration;
	ConVar g_cvMTAssaultRifleAmmo;
	ConVar g_cvMTAutoShotgunAmmo;
	ConVar g_cvMTAutoUpdate;
	ConVar g_cvMTColaBottlesUseDuration;
	ConVar g_cvMTDefibrillatorUseDuration;
	ConVar g_cvMTDifficulty;
	ConVar g_cvMTDisabledGameModes;
	ConVar g_cvMTEnabledGameModes;
	ConVar g_cvMTFirstAidHealPercent;
	ConVar g_cvMTFirstAidKitUseDuration;
	ConVar g_cvMTGameMode;
	ConVar g_cvMTGameModeTypes;
	ConVar g_cvMTGameTypes;
	ConVar g_cvMTGasCanUseDuration;
	ConVar g_cvMTGrenadeLauncherAmmo;
	ConVar g_cvMTGunSwingInterval;
	ConVar g_cvMTGunVerticalPunch;
	ConVar g_cvMTHuntingRifleAmmo;
	ConVar g_cvMTListenSupport;
	ConVar g_cvMTMeleeRange;
	ConVar g_cvMTPainPillsDecayRate;
	ConVar g_cvMTPhysicsPushScale;
	ConVar g_cvMTPipeBombDuration;
	ConVar g_cvMTPluginEnabled;
	ConVar g_cvMTShotgunAmmo;
	ConVar g_cvMTSMGAmmo;
	ConVar g_cvMTSniperRifleAmmo;
	ConVar g_cvMTSurvivorReviveDuration;
	ConVar g_cvMTSurvivorReviveHealth;
	ConVar g_cvMTTankIncapHealth;
	ConVar g_cvMTTempSetting;
	ConVar g_cvMTUpgradePackUseDuration;
#if defined _clientprefs_included
	Cookie g_ckMTAdmin[6];
	Cookie g_ckMTPrefs;
#endif
	DataState g_dsState;
	DataState g_dsState2;
	DataState g_dsState3;

	DynamicDetour g_ddActionCompleteDetour;
	DynamicDetour g_ddBaseEntityCreateDetour;
	DynamicDetour g_ddBaseEntityGetGroundEntityDetour;
	DynamicDetour g_ddBeginChangeLevelDetour;
	DynamicDetour g_ddCanDeployForDetour;
	DynamicDetour g_ddCheckJumpButtonDetour;
	DynamicDetour g_ddDeathFallCameraEnableDetour;
	DynamicDetour g_ddDoAnimationEventDetour;
	DynamicDetour g_ddDoJumpDetour;
	DynamicDetour g_ddEnterGhostStateDetour;
	DynamicDetour g_ddEnterStasisDetour;
	DynamicDetour g_ddEventKilledDetour;
	DynamicDetour g_ddExtinguishDetour;
	DynamicDetour g_ddFallingDetour;
	DynamicDetour g_ddFinishHealingDetour;
	DynamicDetour g_ddFirstSurvivorLeftSafeAreaDetour;
	DynamicDetour g_ddFireBulletDetour;
	DynamicDetour g_ddFlingDetour;
	DynamicDetour g_ddGetMaxClip1Detour;
	DynamicDetour g_ddHitByVomitJarDetour;
	DynamicDetour g_ddIncapacitatedAsTankDetour;
	DynamicDetour g_ddInitialContainedActionDetour;
	DynamicDetour g_ddITExpiredDetour;
	DynamicDetour g_ddLadderDismountDetour;
	DynamicDetour g_ddLadderMountDetour;
	DynamicDetour g_ddLauncherDirectionDetour;
	DynamicDetour g_ddLeaveStasisDetour;
	DynamicDetour g_ddMaxCarryDetour;
	DynamicDetour g_ddPipeBombProjectileCreateDetour;
	DynamicDetour g_ddPreThinkDetour;
	DynamicDetour g_ddReplaceTankDetour;
	DynamicDetour g_ddRevivedDetour;
	DynamicDetour g_ddSecondaryAttackDetour;
	DynamicDetour g_ddSecondaryAttackDetour2;
	DynamicDetour g_ddSelectWeightedSequenceDetour;
	DynamicDetour g_ddSetMainActivityDetour;
	DynamicDetour g_ddShovedByPounceLandingDetour;
	DynamicDetour g_ddShovedBySurvivorDetour;
	DynamicDetour g_ddSpawnTankDetour;
	DynamicDetour g_ddStaggeredDetour;
	DynamicDetour g_ddStartActionDetour;
	DynamicDetour g_ddStartHealingDetour;
	DynamicDetour g_ddStartRevivingDetour;
	DynamicDetour g_ddTankClawDoSwingDetour;
	DynamicDetour g_ddTankClawGroundPoundDetour;
	DynamicDetour g_ddTankClawPlayerHitDetour;
	DynamicDetour g_ddTankClawPrimaryAttackDetour;
	DynamicDetour g_ddTankRockCreateDetour;
	DynamicDetour g_ddTankRockDetonateDetour;
	DynamicDetour g_ddTankRockReleaseDetour;
	DynamicDetour g_ddTestMeleeSwingCollisionDetour;
	DynamicDetour g_ddThrowActivateAbilityDetour;
	DynamicDetour g_ddUseDetour;
	DynamicDetour g_ddUseDetour2;
	DynamicDetour g_ddVomitedUponDetour;

	float g_flActionDurationReward[4];
	float g_flAttackBoostReward[4];
	float g_flAttackInterval;
	float g_flBurnDuration;
	float g_flBurntSkin;
	float g_flClawDamage;
	float g_flConfigDelay;
	float g_flDamageBoostReward[4];
	float g_flDamageResistanceReward[4];
	float g_flDefaultAmmoPackUseDuration;
	float g_flDefaultColaBottlesUseDuration;
	float g_flDefaultDefibrillatorUseDuration;
	float g_flDefaultFirstAidHealPercent;
	float g_flDefaultFirstAidKitUseDuration;
	float g_flDefaultGasCanUseDuration;
	float g_flDefaultGunSwingInterval;
	float g_flDefaultPhysicsPushScale;
	float g_flDefaultPipeBombDuration;
	float g_flDefaultSurvivorReviveDuration;
	float g_flDefaultUpgradePackUseDuration;
	float g_flDifficultyDamage[4];
	float g_flExtrasDelay;
	float g_flForceSpawn;
	float g_flHealPercentMultiplier;
	float g_flHealPercentReward[4];
	float g_flHittableDamage;
	float g_flIdleCheck;
	float g_flIncapDamageMultiplier;
	float g_flJumpHeightReward[4];
	float g_flLoopingVoicelineInterval[4];
	float g_flPipeBombDurationReward[4];
	float g_flPunchForce;
	float g_flPunchResistanceReward[4];
	float g_flPunchThrow;
	float g_flRegularDelay;
	float g_flRegularInterval;
	float g_flRewardChance[4];
	float g_flRewardDuration[4];
	float g_flRewardPercentage[4];
	float g_flRockDamage;
	float g_flRunSpeed;
	float g_flShoveDamageReward[4];
	float g_flShoveRateReward[4];
	float g_flSpeedBoostReward[4];
	float g_flSurvivalDelay;
	float g_flThrowInterval;
	float g_flTickInterval;

	GameData g_gdMutantTanks;

	GlobalForward g_gfAbilityActivatedForward;
	GlobalForward g_gfAbilityCheckForward;
	GlobalForward g_gfButtonPressedForward;
	GlobalForward g_gfButtonReleasedForward;
	GlobalForward g_gfChangeTypeForward;
	GlobalForward g_gfCombineAbilitiesForward;
	GlobalForward g_gfConfigsLoadForward;
	GlobalForward g_gfConfigsLoadedForward;
	GlobalForward g_gfCopyStatsForward;
	GlobalForward g_gfDisplayMenuForward;
	GlobalForward g_gfEventFiredForward;
	GlobalForward g_gfFatalFallingForward;
	GlobalForward g_gfHookEventForward;
	GlobalForward g_gfLogMessageForward;
	GlobalForward g_gfMenuItemDisplayedForward;
	GlobalForward g_gfMenuItemSelectedForward;
	GlobalForward g_gfPlayerEventKilledForward;
	GlobalForward g_gfPlayerHitByVomitJarForward;
	GlobalForward g_gfPlayerShovedBySurvivorForward;
	GlobalForward g_gfPluginCheckForward;
	GlobalForward g_gfPluginEndForward;
	GlobalForward g_gfPostTankSpawnForward;
	GlobalForward g_gfResetTimersForward;
	GlobalForward g_gfRewardSurvivorForward;
	GlobalForward g_gfRockBreakForward;
	GlobalForward g_gfRockThrowForward;
	GlobalForward g_gfSettingsCachedForward;
	GlobalForward g_gfTypeChosenForward;
#if defined _updater_included
	GlobalForward g_gfPluginUpdateForward;
#endif
	Handle g_hRegularWavesTimer;
	Handle g_hSDKDeafen;
	Handle g_hSDKFirstContainedResponder;
	Handle g_hSDKGetMaxClip1;
	Handle g_hSDKGetMissionFirstMap;
	Handle g_hSDKGetMissionInfo;
	Handle g_hSDKGetName;
	Handle g_hSDKGetRefEHandle;
	Handle g_hSDKGetUseAction;
	Handle g_hSDKGetWeaponID;
	Handle g_hSDKGetWeaponInfo;
	Handle g_hSDKHasAnySurvivorLeftSafeArea;
	Handle g_hSDKHasConfigurableDifficultySetting;
	Handle g_hSDKIsCoopMode;
	Handle g_hSDKIsFirstMapInScenario;
	Handle g_hSDKIsInStasis;
	Handle g_hSDKIsMissionFinalMap;
	Handle g_hSDKIsRealismMode;
	Handle g_hSDKIsScavengeMode;
	Handle g_hSDKIsSurvivalMode;
	Handle g_hSDKIsVersusMode;
	Handle g_hSDKITExpired;
	Handle g_hSDKKeyValuesGetString;
	Handle g_hSDKLeaveStasis;
	Handle g_hSDKMaterializeFromGhost;
	Handle g_hSDKRevive;
	Handle g_hSDKRockDetonate;
	Handle g_hSDKRoundRespawn;
	Handle g_hSDKShovedBySurvivor;
	Handle g_hSDKStagger;
	Handle g_hSDKVomitedUpon;
	Handle g_hSurvivalTimer;
	Handle g_hTankWaveTimer;

	int g_iAccessFlags;
	int g_iAmmoBoostReward[4];
	int g_iAmmoRegenReward[4];
	int g_iAnnounceArrival;
	int g_iAnnounceDeath;
	int g_iAnnounceKill;
	int g_iArrivalMessage;
	int g_iArrivalSound;
	int g_iAttackerOffset;
	int g_iAutoAggravate;
	int g_iAutoUpdate;
	int g_iBaseHealth;
	int g_iBulletImmunity;
	int g_iBunnyHopReward[4];
	int g_iBurstDoorsReward[4];
	int g_iCheckAbilities;
	int g_iChosenType;
	int g_iCleanKillsReward[4];
	int g_iConfigCreate;
	int g_iConfigEnable;
	int g_iConfigExecute;
	int g_iConfigMode;
	int g_iCreditIgniters;
	int g_iCurrentLine;
	int g_iCurrentMode;
	int g_iDeathDetails;
	int g_iDeathMessage;
	int g_iDeathRevert;
	int g_iDeathSound;
	int g_iDefaultMeleeRange;
	int g_iDefaultSurvivorReviveHealth;
	int g_iDefaultTankIncapHealth;
	int g_iDetourCount;
	int g_iDisplayHealth;
	int g_iDisplayHealthType;
	int g_iExplosiveImmunity;
	int g_iExtraHealth;
	int g_iFileTimeOld[8];
	int g_iFileTimeNew[8];
	int g_iFinaleAmount;
	int g_iFinaleMaxTypes[11];
	int g_iFinaleMinTypes[11];
	int g_iFinalesOnly;
	int g_iFinaleWave[11];
	int g_iFireImmunity;
	int g_iFriendlyFireReward[4];
	int g_iGameModeTypes;
	int g_iGroundPound;
	int g_iHealthRegenReward[4];
	int g_iHittableImmunity;
	int g_iHollowpointAmmoReward[4];
	int g_iHumanCooldown;
	int g_iHumanMultiplierMode;
	int g_iIdleCheckMode;
	int g_iIgnoreLevel;
	int g_iIgnoreLevel2;
	int g_iIgnoreLevel3;
	int g_iIgnoreLevel4;
	int g_iIgnoreLevel5;
	int g_iImmunityFlags;
	int g_iInextinguishableFireReward[4];
	int g_iInfectedHealth[2048];
	int g_iInfiniteAmmoReward[4];
	int g_iIntentionOffset;
	int g_iKillMessage;
	int g_iLadderActionsReward[4];
	int g_iLadyKillerReward[4];
	int g_iLauncher;
	int g_iLifeLeechReward[4];
	int g_iLimitExtras;
	int g_iListenSupport;
	int g_iLogCommands;
	int g_iLogMessages;
	int g_iMasterControl;
	int g_iMaxType;
	int g_iMeleeImmunity;
	int g_iMeleeOffset;
	int g_iMeleeRangeReward[4];
	int g_iMidairDashesLimit;
	int g_iMidairDashesReward[4];
	int g_iMinType;
	int g_iMinimumHumans;
	int g_iMultiplyHealth;
	int g_iParserViewer;
	int g_iParticleEffectVisual[4];
	int g_iPatchCount;
	int g_iPlatformType;
	int g_iPlayerCount[3];
	int g_iPluginEnabled;
	int g_iPrefsNotify[4];
	int g_iRecoilDampenerReward[4];
	int g_iRegularAmount;
	int g_iRegularCount;
	int g_iRegularLimit;
	int g_iRegularMaxType;
	int g_iRegularMinType;
	int g_iRegularMode;
	int g_iRegularWave;
	int g_iRequiresHumans;
	int g_iRespawnLoadoutReward[4];
	int g_iReviveHealthReward[4];
	int g_iRewardBots[4];
	int g_iRewardEffect[4];
	int g_iRewardEnabled[4];
	int g_iRewardNotify[4];
	int g_iRewardVisual[4];
	int g_iRockSound;
	int g_iScaleDamage;
	int g_iSection;
	int g_iShareRewards[4];
	int g_iShovePenaltyReward[4];
	int g_iSignatureCount;
	int g_iSkipIncap;
	int g_iSkipTaunt;
	int g_iSledgehammerRoundsReward[4];
	int g_iSpawnLimit;
	int g_iSpawnEnabled;
	int g_iSpawnMode;
	int g_iSpecialAmmoReward[4];
	int g_iStackLimits[7];
	int g_iStackRewards[4];
	int g_iStasisMode;
	int g_iSurvivalBlock;
	int g_iSweepFist;
	int g_iTankCount;
	int g_iTankEnabled;
	int g_iTankModel;
	int g_iTankWave;
	int g_iTeamID[2048];
	int g_iTeamID2[2048];
	int g_iTeammateLimit;
	int g_iThornsReward[4];
	int g_iTypeCounter[2];
	int g_iUsefulRewards[4];
	int g_iVerticalPunchOffset;
	int g_iVocalizeArrival;
	int g_iVocalizeDeath;
	int g_iVoicePitchVisual[4];
	int g_iVomitImmunity;
#if defined _adminmenu_included
	TopMenu g_tmMTMenu;
#endif
	UserMsg g_umSayText2;
}

esGeneral g_esGeneral;

enum struct esAdmin
{
	int g_iAccessFlags[MAXPLAYERS + 1];
	int g_iImmunityFlags[MAXPLAYERS + 1];
}

esAdmin g_esAdmin[MT_MAXTYPES + 1];

enum struct esDeveloper
{
	bool g_bDevVisual;

	char g_sDevFallVoiceline[64];
	char g_sDevFlashlight[64];
	char g_sDevGlowOutline[64];
	char g_sDevLoadout[384];
	char g_sDevSkinColor[64];

	float g_flDevActionDuration;
	float g_flDevAttackBoost;
	float g_flDevDamageBoost;
	float g_flDevDamageResistance;
	float g_flDevHealPercent;
	float g_flDevJumpHeight;
	float g_flDevPipeBombDuration;
	float g_flDevPunchResistance;
	float g_flDevRewardDuration;
	float g_flDevShoveDamage;
	float g_flDevShoveRate;
	float g_flDevSpeedBoost;

	int g_iDevAccess;
	int g_iDevAmmoRegen;
	int g_iDevHealthRegen;
	int g_iDevInfiniteAmmo;
	int g_iDevLifeLeech;
	int g_iDevMeleeRange;
	int g_iDevMidairDashes;
	int g_iDevPanelLevel;
	int g_iDevParticle;
	int g_iDevReviveHealth;
	int g_iDevRewardTypes;
	int g_iDevSpecialAmmo;
	int g_iDevVoicePitch;
	int g_iDevWeaponSkin;
}

esDeveloper g_esDeveloper[MAXPLAYERS + 1];

enum struct esPlayer
{
	bool g_bAdminMenu;
	bool g_bApplyVisuals[7];
	bool g_bArtificial;
	bool g_bBlood;
	bool g_bBlur;
	bool g_bBoss;
	bool g_bCombo;
	bool g_bDied;
	bool g_bDualWielding;
	bool g_bElectric;
	bool g_bFallDamage;
	bool g_bFalling;
	bool g_bFallTracked;
	bool g_bFatalFalling;
	bool g_bFire;
	bool g_bFirstSpawn;
	bool g_bIce;
	bool g_bIgnoreCmd;
	bool g_bInitialRound;
	bool g_bKeepCurrentType;
	bool g_bLastLife;
	bool g_bMeteor;
	bool g_bRainbowColor;
	bool g_bRandomized;
	bool g_bReleasedJump;
	bool g_bReplaceSelf;
	bool g_bSetup;
	bool g_bSmoke;
	bool g_bSpit;
	bool g_bStasis;
	bool g_bThirdPerson;
#if defined _ThirdPersonShoulder_Detect_included
	bool g_bThirdPerson2;
#endif
	bool g_bTransformed;
	bool g_bVomited;

	char g_sBodyColor[64];
	char g_sBodyColorVisual[64];
	char g_sBodyColorVisual2[64];
	char g_sBodyColorVisual3[64];
	char g_sBodyColorVisual4[64];
	char g_sComboSet[320];
	char g_sHealthCharacters[4];
	char g_sFallVoiceline[64];
	char g_sFallVoicelineReward[64];
	char g_sFallVoicelineReward2[64];
	char g_sFallVoicelineReward3[64];
	char g_sFallVoicelineReward4[64];
	char g_sFlameColor[64];
	char g_sFlashlightColor[64];
	char g_sGlowColor[64];
	char g_sItemReward[320];
	char g_sItemReward2[320];
	char g_sItemReward3[320];
	char g_sItemReward4[320];
	char g_sLightColor[64];
	char g_sLightColorVisual[64];
	char g_sLightColorVisual2[64];
	char g_sLightColorVisual3[64];
	char g_sLightColorVisual4[64];
	char g_sLoopingVoiceline[64];
	char g_sLoopingVoicelineVisual[64];
	char g_sLoopingVoicelineVisual2[64];
	char g_sLoopingVoicelineVisual3[64];
	char g_sLoopingVoicelineVisual4[64];
	char g_sOutlineColor[64];
	char g_sOutlineColorVisual[64];
	char g_sOutlineColorVisual2[64];
	char g_sOutlineColorVisual3[64];
	char g_sOutlineColorVisual4[64];
	char g_sOzTankColor[64];
	char g_sPropTankColor[64];
	char g_sRockColor[64];
	char g_sScreenColor[64];
	char g_sScreenColorVisual[64];
	char g_sScreenColorVisual2[64];
	char g_sScreenColorVisual3[64];
	char g_sScreenColorVisual4[64];
	char g_sSkinColor[64];
	char g_sSteamID32[64];
	char g_sSteam3ID[64];
	char g_sStoredThrowable[32];
	char g_sStoredMedkit[32];
	char g_sStoredPills[32];
	char g_sTankName[33];
	char g_sTireColor[64];
	char g_sWeaponPrimary[32];
	char g_sWeaponSecondary[32];
	char g_sWeaponThrowable[32];
	char g_sWeaponMedkit[32];
	char g_sWeaponPills[32];

	float g_flActionDuration;
	float g_flActionDurationReward[4];
	float g_flAttackBoost;
	float g_flAttackBoostReward[4];
	float g_flAttackInterval;
	float g_flBurnDuration;
	float g_flBurntSkin;
	float g_flClawDamage;
	float g_flComboChance[10];
	float g_flComboDamage[10];
	float g_flComboDeathChance[10];
	float g_flComboDeathRange[10];
	float g_flComboDelay[10];
	float g_flComboDuration[10];
	float g_flComboInterval[10];
	float g_flComboMaxRadius[10];
	float g_flComboMinRadius[10];
	float g_flComboRange[10];
	float g_flComboRangeChance[10];
	float g_flComboRockChance[10];
	float g_flComboSpeed[10];
	float g_flComboTypeChance[7];
	float g_flDamageBoost;
	float g_flDamageBoostReward[4];
	float g_flDamageResistance;
	float g_flDamageResistanceReward[4];
	float g_flHealPercent;
	float g_flHealPercentMultiplier;
	float g_flHealPercentReward[4];
	float g_flHittableDamage;
	float g_flIncapDamageMultiplier;
	float g_flJumpHeight;
	float g_flJumpHeightReward[4];
	float g_flLastAttackTime;
	float g_flLastJumpTime;
	float g_flLastThrowTime;
	float g_flLastPushTime;
	float g_flLoopingVoicelineInterval[4];
	float g_flPipeBombDuration;
	float g_flPipeBombDurationReward[4];
	float g_flPreFallZ;
	float g_flPropsChance[9];
	float g_flPunchForce;
	float g_flPunchResistance;
	float g_flPunchResistanceReward[4];
	float g_flPunchThrow;
	float g_flRandomDuration;
	float g_flRandomInterval;
	float g_flRewardChance[4];
	float g_flRewardDuration[4];
	float g_flRewardPercentage[4];
	float g_flRewardTime[7];
	float g_flRockDamage;
	float g_flRunSpeed;
	float g_flShoveDamage;
	float g_flShoveDamageReward[4];
	float g_flShoveRate;
	float g_flShoveRateReward[4];
	float g_flSpeedBoost;
	float g_flSpeedBoostReward[4];
	float g_flStaggerTime;
	float g_flThrowInterval;
	float g_flTransformDelay;
	float g_flTransformDuration;
	float g_flVisualTime[7];

	Handle g_hHudTimer;

	int g_iAccessFlags;
	int g_iAmmoBoost;
	int g_iAmmoBoostReward[4];
	int g_iAmmoRegen;
	int g_iAmmoRegenReward[4];
	int g_iAnnounceArrival;
	int g_iAnnounceDeath;
	int g_iAnnounceKill;
	int g_iArrivalMessage;
	int g_iArrivalSound;
	int g_iBaseHealth;
	int g_iBlur;
	int g_iBodyEffects;
	int g_iBossHealth[4];
	int g_iBossStageCount;
	int g_iBossStages;
	int g_iBossType[4];
	int g_iBulletImmunity;
	int g_iBunnyHop;
	int g_iBunnyHopReward[4];
	int g_iBurstDoors;
	int g_iBurstDoorsReward[4];
	int g_iCheckAbilities;
	int g_iClawCount;
	int g_iClawDamage;
	int g_iCleanKills;
	int g_iCleanKillsReward[4];
	int g_iComboCooldown[10];
	int g_iComboRangeCooldown[10];
	int g_iComboRockCooldown[10];
	int g_iCooldown;
	int g_iCrownColor[4];
	int g_iDeathDetails;
	int g_iDeathMessage;
	int g_iDeathRevert;
	int g_iDeathSound;
	int g_iDisplayHealth;
	int g_iDisplayHealthType;
	int g_iEffect[2];
	int g_iExplosiveImmunity;
	int g_iExtraHealth;
	int g_iFallPasses;
	int g_iFavoriteType;
	int g_iFireImmunity;
	int g_iFlame[2];
	int g_iFlameColor[4];
	int g_iFlashlight;
	int g_iFlashlightColor[4];
	int g_iFriendlyFire;
	int g_iFriendlyFireReward[4];
	int g_iGlowColor[3];
	int g_iGlowEnabled;
	int g_iGlowFlashing;
	int g_iGlowMaxRange;
	int g_iGlowMinRange;
	int g_iGlowType;
	int g_iGroundPound;
	int g_iHealthRegen;
	int g_iHealthRegenReward[4];
	int g_iHittableImmunity;
	int g_iHollowpointAmmo;
	int g_iHollowpointAmmoReward[4];
	int g_iHudPanelLevel;
	int g_iHudPanelPages;
	int g_iHumanMultiplierMode;
	int g_iImmunityFlags;
	int g_iIncapCount;
	int g_iInextinguishableFire;
	int g_iInextinguishableFireReward[4];
	int g_iInfiniteAmmo;
	int g_iInfiniteAmmoReward[4];
	int g_iKillCount;
	int g_iKillMessage;
	int g_iLadderActions;
	int g_iLadderActionsReward[4];
	int g_iLadyKillerCount;
	int g_iLadyKillerLimit;
	int g_iLadyKillerReward[4];
	int g_iLastButtons;
	int g_iLastFireAttacker;
	int g_iLifeLeech;
	int g_iLifeLeechReward[4];
	int g_iLight[9];
	int g_iLightColor[4];
	int g_iMaxClip[2];
	int g_iMeleeImmunity;
	int g_iMeleeRange;
	int g_iMeleeRangeReward[4];
	int g_iMidairDashesCount;
	int g_iMidairDashesLimit;
	int g_iMidairDashesReward[4];
	int g_iMinimumHumans;
	int g_iMiscCount;
	int g_iMiscDamage;
	int g_iMultiplyHealth;
	int g_iNotify;
	int g_iOldTankType;
	int g_iOzTank[2];
	int g_iOzTankColor[4];
	int g_iParticleEffect;
	int g_iParticleEffectVisual[4];
	int g_iPersonalType;
	int g_iPrefsAccess;
	int g_iPrefsNotify[4];
	int g_iPropCount;
	int g_iPropDamage;
	int g_iPropsAttached;
	int g_iPropaneTank;
	int g_iPropTankColor[4];
	int g_iRandomTank;
	int g_iRecoilDampener;
	int g_iRecoilDampenerReward[4];
	int g_iRespawnLoadoutReward[4];
	int g_iReviveCount;
	int g_iReviveHealth;
	int g_iReviveHealthReward[4];
	int g_iReviver;
	int g_iRewardBots[4];
	int g_iRewardEffect[4];
	int g_iRewardEnabled[4];
	int g_iRewardNotify[4];
	int g_iRewardStack[7];
	int g_iRewardTypes;
	int g_iRewardVisual[4];
	int g_iRewardVisuals;
	int g_iRock[20];
	int g_iRockColor[4];
	int g_iRockCount;
	int g_iRockDamage;
	int g_iRockEffects;
	int g_iRockModel;
	int g_iRockSound;
	int g_iScreenColorVisual[4];
	int g_iShareRewards[4];
	int g_iShovePenalty;
	int g_iShovePenaltyReward[4];
	int g_iSkinColor[4];
	int g_iSkipIncap;
	int g_iSkipTaunt;
	int g_iSledgehammerRounds;
	int g_iSledgehammerRoundsReward[4];
	int g_iSpawnType;
	int g_iSpecialAmmo;
	int g_iSpecialAmmoReward[4];
	int g_iStackLimits[7];
	int g_iStackRewards[4];
	int g_iSurvivorDamage;
	int g_iSweepFist;
	int g_iTankDamage[MAXPLAYERS + 1];
	int g_iTankHealth;
	int g_iTankModel;
	int g_iTankNote;
	int g_iTankType;
	int g_iTeammateLimit;
	int g_iThorns;
	int g_iThornsReward[4];
	int g_iThrownRock[2048];
	int g_iTire[2];
	int g_iTireColor[4];
	int g_iTransformType[10];
	int g_iUsefulRewards[4];
	int g_iUserID;
	int g_iUserID2;
	int g_iVocalizeArrival;
	int g_iVocalizeDeath;
	int g_iVoicePitch;
	int g_iVoicePitchVisual[4];
	int g_iVomitImmunity;
	int g_iWeaponInfo[4];
	int g_iWeaponInfo2;
}

esPlayer g_esPlayer[MAXPLAYERS + 1];

enum struct esTank
{
	char g_sBodyColorVisual[64];
	char g_sBodyColorVisual2[64];
	char g_sBodyColorVisual3[64];
	char g_sBodyColorVisual4[64];
	char g_sComboSet[320];
	char g_sFallVoicelineReward[64];
	char g_sFallVoicelineReward2[64];
	char g_sFallVoicelineReward3[64];
	char g_sFallVoicelineReward4[64];
	char g_sFlameColor[64];
	char g_sFlashlightColor[64];
	char g_sGlowColor[64];
	char g_sHealthCharacters[4];
	char g_sItemReward[320];
	char g_sItemReward2[320];
	char g_sItemReward3[320];
	char g_sItemReward4[320];
	char g_sLightColorVisual[64];
	char g_sLightColorVisual2[64];
	char g_sLightColorVisual3[64];
	char g_sLightColorVisual4[64];
	char g_sLoopingVoicelineVisual[64];
	char g_sLoopingVoicelineVisual2[64];
	char g_sLoopingVoicelineVisual3[64];
	char g_sLoopingVoicelineVisual4[64];
	char g_sOutlineColorVisual[64];
	char g_sOutlineColorVisual2[64];
	char g_sOutlineColorVisual3[64];
	char g_sOutlineColorVisual4[64];
	char g_sOzTankColor[64];
	char g_sPropTankColor[64];
	char g_sRockColor[64];
	char g_sScreenColorVisual[64];
	char g_sScreenColorVisual2[64];
	char g_sScreenColorVisual3[64];
	char g_sScreenColorVisual4[64];
	char g_sSkinColor[64];
	char g_sTankName[33];
	char g_sTireColor[64];

	float g_flActionDurationReward[4];
	float g_flAttackBoostReward[4];
	float g_flAttackInterval;
	float g_flBurnDuration;
	float g_flBurntSkin;
	float g_flClawDamage;
	float g_flCloseAreasOnly;
	float g_flComboChance[10];
	float g_flComboDamage[10];
	float g_flComboDeathChance[10];
	float g_flComboDeathRange[10];
	float g_flComboDelay[10];
	float g_flComboDuration[10];
	float g_flComboInterval[10];
	float g_flComboMaxRadius[10];
	float g_flComboMinRadius[10];
	float g_flComboRange[10];
	float g_flComboRangeChance[10];
	float g_flComboRockChance[10];
	float g_flComboSpeed[10];
	float g_flComboTypeChance[7];
	float g_flDamageBoostReward[4];
	float g_flDamageResistanceReward[4];
	float g_flHealPercentMultiplier;
	float g_flHealPercentReward[4];
	float g_flHittableDamage;
	float g_flIncapDamageMultiplier;
	float g_flJumpHeightReward[4];
	float g_flLoopingVoicelineInterval[4];
	float g_flOpenAreasOnly;
	float g_flPipeBombDurationReward[4];
	float g_flPropsChance[9];
	float g_flPunchForce;
	float g_flPunchResistanceReward[4];
	float g_flPunchThrow;
	float g_flRandomDuration;
	float g_flRandomInterval;
	float g_flRewardChance[4];
	float g_flRewardDuration[4];
	float g_flRewardPercentage[4];
	float g_flRockDamage;
	float g_flRunSpeed;
	float g_flShoveDamageReward[4];
	float g_flShoveRateReward[4];
	float g_flSpeedBoostReward[4];
	float g_flTankChance;
	float g_flThrowInterval;
	float g_flTransformDelay;
	float g_flTransformDuration;

	int g_iAbilityCount;
	int g_iAccessFlags;
	int g_iAmmoBoostReward[4];
	int g_iAmmoRegenReward[4];
	int g_iAnnounceArrival;
	int g_iAnnounceDeath;
	int g_iAnnounceKill;
	int g_iArrivalMessage;
	int g_iArrivalSound;
	int g_iAutoAggravate;
	int g_iBaseHealth;
	int g_iBodyEffects;
	int g_iBossBaseType;
	int g_iBossHealth[4];
	int g_iBossLimit;
	int g_iBossStages;
	int g_iBossType[4];
	int g_iBulletImmunity;
	int g_iBunnyHopReward[4];
	int g_iBurstDoorsReward[4];
	int g_iCheckAbilities;
	int g_iCleanKillsReward[4];
	int g_iComboCooldown[10];
	int g_iComboRangeCooldown[10];
	int g_iComboRockCooldown[10];
	int g_iCrownColor[4];
	int g_iDeathDetails;
	int g_iDeathMessage;
	int g_iDeathRevert;
	int g_iDeathSound;
	int g_iDisplayHealth;
	int g_iDisplayHealthType;
	int g_iExplosiveImmunity;
	int g_iExtraHealth;
	int g_iFinaleTank;
	int g_iFireImmunity;
	int g_iFlameColor[4];
	int g_iFlashlightColor[4];
	int g_iFriendlyFireReward[4];
	int g_iGameType;
	int g_iGlowColor[3];
	int g_iGlowEnabled;
	int g_iGlowFlashing;
	int g_iGlowMaxRange;
	int g_iGlowMinRange;
	int g_iGlowType;
	int g_iGroundPound;
	int g_iHealthRegenReward[4];
	int g_iHittableImmunity;
	int g_iHollowpointAmmoReward[4];
	int g_iHumanMultiplierMode;
	int g_iHumanSupport;
	int g_iImmunityFlags;
	int g_iInextinguishableFireReward[4];
	int g_iInfiniteAmmoReward[4];
	int g_iKillMessage;
	int g_iLadderActionsReward[4];
	int g_iLadyKillerReward[4];
	int g_iLifeLeechReward[4];
	int g_iLightColor[4];
	int g_iMeleeImmunity;
	int g_iMeleeRangeReward[4];
	int g_iMenuEnabled;
	int g_iMidairDashesLimit;
	int g_iMidairDashesReward[4];
	int g_iMinimumHumans;
	int g_iMultiplyHealth;
	int g_iOzTankColor[4];
	int g_iParticleEffectVisual[4];
	int g_iPrefsNotify[4];
	int g_iPropsAttached;
	int g_iPropTankColor[4];
	int g_iRealType[2];
	int g_iRandomTank;
	int g_iRecoilDampenerReward[4];
	int g_iRecordedType[2];
	int g_iRequiresHumans;
	int g_iRespawnLoadoutReward[4];
	int g_iReviveHealthReward[4];
	int g_iRewardBots[4];
	int g_iRewardEffect[4];
	int g_iRewardEnabled[4];
	int g_iRewardNotify[4];
	int g_iRewardVisual[4];
	int g_iRockColor[4];
	int g_iRockEffects;
	int g_iRockModel;
	int g_iRockSound;
	int g_iShareRewards[4];
	int g_iShovePenaltyReward[4];
	int g_iSkinColor[4];
	int g_iSkipIncap;
	int g_iSkipTaunt;
	int g_iSledgehammerRoundsReward[4];
	int g_iSpawnEnabled;
	int g_iSpawnType;
	int g_iSpecialAmmoReward[4];
	int g_iStackLimits[7];
	int g_iStackRewards[4];
	int g_iSweepFist;
	int g_iTankEnabled;
	int g_iTankModel;
	int g_iTankNote;
	int g_iTeammateLimit;
	int g_iThornsReward[4];
	int g_iTireColor[4];
	int g_iTransformType[10];
	int g_iTypeLimit;
	int g_iUsefulRewards[4];
	int g_iVocalizeArrival;
	int g_iVocalizeDeath;
	int g_iVoicePitchVisual[4];
	int g_iVomitImmunity;
}

esTank g_esTank[MT_MAXTYPES + 1];

enum struct esCache
{
	char g_sBodyColorVisual[64];
	char g_sBodyColorVisual2[64];
	char g_sBodyColorVisual3[64];
	char g_sBodyColorVisual4[64];
	char g_sComboSet[320];
	char g_sFallVoicelineReward[64];
	char g_sFallVoicelineReward2[64];
	char g_sFallVoicelineReward3[64];
	char g_sFallVoicelineReward4[64];
	char g_sFlameColor[64];
	char g_sFlashlightColor[64];
	char g_sGlowColor[64];
	char g_sHealthCharacters[4];
	char g_sItemReward[320];
	char g_sItemReward2[320];
	char g_sItemReward3[320];
	char g_sItemReward4[320];
	char g_sLightColorVisual[64];
	char g_sLightColorVisual2[64];
	char g_sLightColorVisual3[64];
	char g_sLightColorVisual4[64];
	char g_sLoopingVoicelineVisual[64];
	char g_sLoopingVoicelineVisual2[64];
	char g_sLoopingVoicelineVisual3[64];
	char g_sLoopingVoicelineVisual4[64];
	char g_sOutlineColorVisual[64];
	char g_sOutlineColorVisual2[64];
	char g_sOutlineColorVisual3[64];
	char g_sOutlineColorVisual4[64];
	char g_sOzTankColor[64];
	char g_sPropTankColor[64];
	char g_sRockColor[64];
	char g_sScreenColorVisual[64];
	char g_sScreenColorVisual2[64];
	char g_sScreenColorVisual3[64];
	char g_sScreenColorVisual4[64];
	char g_sSkinColor[64];
	char g_sTankName[33];
	char g_sTireColor[64];

	float g_flActionDurationReward[4];
	float g_flAttackBoostReward[4];
	float g_flAttackInterval;
	float g_flBurnDuration;
	float g_flBurntSkin;
	float g_flClawDamage;
	float g_flComboChance[10];
	float g_flComboDamage[10];
	float g_flComboDeathChance[10];
	float g_flComboDeathRange[10];
	float g_flComboDelay[10];
	float g_flComboDuration[10];
	float g_flComboInterval[10];
	float g_flComboMaxRadius[10];
	float g_flComboMinRadius[10];
	float g_flComboRange[10];
	float g_flComboRangeChance[10];
	float g_flComboRockChance[10];
	float g_flComboSpeed[10];
	float g_flComboTypeChance[7];
	float g_flDamageBoostReward[4];
	float g_flDamageResistanceReward[4];
	float g_flHealPercentMultiplier;
	float g_flHealPercentReward[4];
	float g_flHittableDamage;
	float g_flIncapDamageMultiplier;
	float g_flJumpHeightReward[4];
	float g_flLoopingVoicelineInterval[4];
	float g_flPipeBombDurationReward[4];
	float g_flPropsChance[9];
	float g_flPunchForce;
	float g_flPunchResistanceReward[4];
	float g_flPunchThrow;
	float g_flRandomDuration;
	float g_flRandomInterval;
	float g_flRewardChance[4];
	float g_flRewardDuration[4];
	float g_flRewardPercentage[4];
	float g_flRockDamage;
	float g_flRunSpeed;
	float g_flShoveDamageReward[4];
	float g_flShoveRateReward[4];
	float g_flSpeedBoostReward[4];
	float g_flThrowInterval;
	float g_flTransformDelay;
	float g_flTransformDuration;

	int g_iAmmoBoostReward[4];
	int g_iAmmoRegenReward[4];
	int g_iAnnounceArrival;
	int g_iAnnounceDeath;
	int g_iAnnounceKill;
	int g_iArrivalMessage;
	int g_iArrivalSound;
	int g_iAutoAggravate;
	int g_iBaseHealth;
	int g_iBodyEffects;
	int g_iBossHealth[4];
	int g_iBossStages;
	int g_iBossType[4];
	int g_iBulletImmunity;
	int g_iBunnyHopReward[4];
	int g_iBurstDoorsReward[4];
	int g_iCheckAbilities;
	int g_iCleanKillsReward[4];
	int g_iComboCooldown[10];
	int g_iComboRangeCooldown[10];
	int g_iComboRockCooldown[10];
	int g_iCrownColor[4];
	int g_iDeathDetails;
	int g_iDeathMessage;
	int g_iDeathRevert;
	int g_iDeathSound;
	int g_iDisplayHealth;
	int g_iDisplayHealthType;
	int g_iExplosiveImmunity;
	int g_iExtraHealth;
	int g_iFireImmunity;
	int g_iFlameColor[4];
	int g_iFlashlightColor[4];
	int g_iFriendlyFireReward[4];
	int g_iGlowColor[3];
	int g_iGlowEnabled;
	int g_iGlowFlashing;
	int g_iGlowMaxRange;
	int g_iGlowMinRange;
	int g_iGlowType;
	int g_iGroundPound;
	int g_iHealthRegenReward[4];
	int g_iHittableImmunity;
	int g_iHollowpointAmmoReward[4];
	int g_iHumanMultiplierMode;
	int g_iInextinguishableFireReward[4];
	int g_iInfiniteAmmoReward[4];
	int g_iKillMessage;
	int g_iLadderActionsReward[4];
	int g_iLadyKillerReward[4];
	int g_iLifeLeechReward[4];
	int g_iLightColor[4];
	int g_iMidairDashesLimit;
	int g_iMidairDashesReward[4];
	int g_iMeleeImmunity;
	int g_iMeleeRangeReward[4];
	int g_iMinimumHumans;
	int g_iMultiplyHealth;
	int g_iOzTankColor[4];
	int g_iParticleEffectVisual[4];
	int g_iPrefsNotify[4];
	int g_iPropsAttached;
	int g_iPropTankColor[4];
	int g_iRandomTank;
	int g_iRecoilDampenerReward[4];
	int g_iRespawnLoadoutReward[4];
	int g_iReviveHealthReward[4];
	int g_iRewardBots[4];
	int g_iRewardEffect[4];
	int g_iRewardEnabled[4];
	int g_iRewardNotify[4];
	int g_iRewardVisual[4];
	int g_iRockColor[4];
	int g_iRockEffects;
	int g_iRockModel;
	int g_iRockSound;
	int g_iShareRewards[4];
	int g_iShovePenaltyReward[4];
	int g_iSkinColor[4];
	int g_iSkipIncap;
	int g_iSkipTaunt;
	int g_iSledgehammerRoundsReward[4];
	int g_iSpawnEnabled;
	int g_iSpawnType;
	int g_iSpecialAmmoReward[4];
	int g_iStackLimits[7];
	int g_iStackRewards[4];
	int g_iSweepFist;
	int g_iTankEnabled;
	int g_iTankModel;
	int g_iTankNote;
	int g_iTeammateLimit;
	int g_iThornsReward[4];
	int g_iTireColor[4];
	int g_iTransformType[10];
	int g_iUsefulRewards[4];
	int g_iVocalizeArrival;
	int g_iVocalizeDeath;
	int g_iVoicePitchVisual[4];
	int g_iVomitImmunity;
}

esCache g_esCache[MAXPLAYERS + 1];

enum struct esDetour
{
	bool g_bBypassNeeded;
	bool g_bInstalled;
	bool g_bLog;

	char g_sCvars[320];
	char g_sName[128];

	int g_iPostHook;
	int g_iPreHook;
	int g_iType;
}

esDetour g_esDetour[MT_DETOUR_LIMIT];

enum struct esPatch
{
	Address g_adPatch;

	bool g_bInstalled;
	bool g_bLog;
	bool g_bUpdateMemAccess;

	char g_sBypass[192];
	char g_sCvars[320];
	char g_sName[128];
	char g_sOffset[128];
	char g_sPatch[192];
	char g_sSignature[128];
	char g_sVerify[192];

	int g_iLength;
	int g_iOffset;
	int g_iOriginalBytes[MT_PATCH_MAXLEN];
	int g_iPatchBytes[MT_PATCH_MAXLEN];
	int g_iType;
}

esPatch g_esPatch[MT_PATCH_LIMIT];

enum struct esSignature
{
	Address g_adString;

	bool g_bLog;

	char g_sAfter[192];
	char g_sBefore[192];
	char g_sDynamicSig[1024];
	char g_sLibrary[32];
	char g_sName[128];
	char g_sOffset[128];
	char g_sSignature[1024];
	char g_sStart[192];

	SDKLibrary g_sdkLibrary;
}

esSignature g_esSignature[MT_SIGNATURE_LIMIT];

int g_iBossBeamSprite = -1, g_iBossHaloSprite = -1;

public void OnLibraryAdded(const char[] name)
{
#if defined _mtclone_included
	if (StrEqual(name, "mt_clone"))
	{
		g_esGeneral.g_bCloneInstalled = true;
	}
#endif
#if defined _updater_included
	if (StrEqual(name, "updater"))
	{
		Updater_AddPlugin(MT_UPDATE_URL);
	}
#endif
}

public void OnLibraryRemoved(const char[] name)
{
#if defined _mtclone_included
	if (StrEqual(name, "mt_clone"))
	{
		g_esGeneral.g_bCloneInstalled = false;
	}
#endif
}

public void OnAllPluginsLoaded()
{
	if (g_esGeneral.g_gdMutantTanks != null)
	{
		vRegisterDetours();
		vSetupDetours();

		vRegisterPatches();
		vInstallPermanentPatches();
	}
}

public void OnPluginStart()
{
	char sDate[32];
	FormatTime(sDate, sizeof sDate, "%Y-%m-%d", GetTime());
	BuildPath(Path_SM, g_esGeneral.g_sLogFile, sizeof esGeneral::g_sLogFile, "logs/mutant_tanks_%s.log", sDate);

	for (int iDeveloper = 1; iDeveloper <= MaxClients; iDeveloper++)
	{
		vDeveloperSettings(iDeveloper);
	}

	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");
	LoadTranslations("mutant_tanks_names.phrases");

	vMultiTargetFilters(true);
	vRegisterCommands();
	vRegisterConVars();
	vReadGameData();
#if defined _clientprefs_included
	char sName[12], sDescription[36];
	for (int iPos = 0; iPos < (sizeof esGeneral::g_ckMTAdmin); iPos++)
	{
		FormatEx(sName, sizeof sName, "MTAdmin%i", iPos + 1);
		FormatEx(sDescription, sizeof sDescription, "Mutant Tanks Admin Preference #%i", iPos + 1);
		g_esGeneral.g_ckMTAdmin[iPos] = new Cookie(sName, sDescription, CookieAccess_Private);
	}

	g_esGeneral.g_ckMTPrefs = new Cookie("MTPrefs", "Mutant Tanks Preferences", CookieAccess_Private);
#endif
	char sSMPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sSMPath, sizeof sSMPath, MT_CONFIG_FILEPATH);
	CreateDirectory(sSMPath, 511);
	FormatEx(g_esGeneral.g_sSavePath, sizeof esGeneral::g_sSavePath, "%s%s", sSMPath, MT_CONFIG_FILE_MAIN);

	switch (MT_FileExists(MT_CONFIG_FILEPATH, MT_CONFIG_FILE_MAIN, g_esGeneral.g_sSavePath, g_esGeneral.g_sSavePath, sizeof esGeneral::g_sSavePath))
	{
		case true: g_esGeneral.g_iFileTimeOld[0] = GetFileTime(g_esGeneral.g_sSavePath, FileTime_LastChange);
		case false: SetFailState("Unable to load the \"%s\" config file.", g_esGeneral.g_sSavePath);
	}

	g_esGeneral.g_alFilePaths = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
	g_esGeneral.g_bUpdateDoJumpMemAccess = true;
	g_esGeneral.g_bUpdateWeaponInfoMemAccess = true;
	g_esGeneral.g_iPlayerCount[0] = 0;
	g_esGeneral.g_umSayText2 = GetUserMessageId("SayText2");

	vHookGlobalEvents();
	vLateLoad();
}

public void OnMapStart()
{
	g_esGeneral.g_bFinalMap = bIsFinalMap();
	g_esGeneral.g_bNormalMap = bIsNormalMap();
	g_esGeneral.g_bSameMission = bGetMissionName();
	g_iBossBeamSprite = PrecacheModel(SPRITE_LASERBEAM, true);
	g_iBossHaloSprite = PrecacheModel(SPRITE_GLOW, true);

	PrecacheModel(MODEL_CONCRETE_CHUNK, true);
	PrecacheModel(MODEL_GASCAN, true);
	PrecacheModel(MODEL_OXYGENTANK, true);
	PrecacheModel(MODEL_PROPANETANK, true);
	PrecacheModel(MODEL_TANK_MAIN, true);
	PrecacheModel(MODEL_TANK_DLC, true);
	PrecacheModel(MODEL_TIRES, true);
	PrecacheModel(MODEL_TREE_TRUNK, true);
	PrecacheModel(MODEL_WITCH, true);
	PrecacheModel(SPRITE_EXPLODE, true);
	PrecacheModel(SPRITE_LASER, true);

	iPrecacheParticle(PARTICLE_ACHIEVED);
	iPrecacheParticle(PARTICLE_BLOOD);
	iPrecacheParticle(PARTICLE_ELECTRICITY);
	iPrecacheParticle(PARTICLE_FIRE);
	iPrecacheParticle(PARTICLE_FIREWORK);
	iPrecacheParticle(PARTICLE_ICE);
	iPrecacheParticle(PARTICLE_METEOR);
	iPrecacheParticle(PARTICLE_SMOKE);

	switch (g_bSecondGame)
	{
		case true:
		{
			PrecacheModel(MODEL_FIREWORKCRATE, true);
			PrecacheModel(MODEL_TANK_L4D1, true);
			PrecacheModel(MODEL_WITCHBRIDE, true);

			PrecacheSound(SOUND_EXPLOSION2, true);
			PrecacheSound(SOUND_SPIT, true);

			iPrecacheParticle(PARTICLE_GORE);
			iPrecacheParticle(PARTICLE_SPIT);
			iPrecacheParticle(PARTICLE_SPIT2);
		}
		case false: PrecacheSound(SOUND_EXPLOSION1, true);
	}

	PrecacheSound(SOUND_ACHIEVEMENT, true);
	PrecacheSound(SOUND_DAMAGE, true);
	PrecacheSound(SOUND_DAMAGE2, true);
	PrecacheSound(SOUND_DEATH, true);
	PrecacheSound(SOUND_ELECTRICITY, true);
	PrecacheSound(SOUND_METAL, true);
	PrecacheSound(SOUND_NULL, true);
	PrecacheSound(SOUND_SPAWN, true);
	PrecacheSound(SOUND_THROWN, true);

	vResetPlugin();
	vResetLadyKiller(false);
	vToggleLogging(1);

	AddNormalSoundHook(FallSoundHook);
	AddNormalSoundHook(RockSoundHook);
	AddNormalSoundHook(VoiceSoundHook);
}

public void OnClientPutInServer(int client)
{
	g_esPlayer[client].g_iUserID = GetClientUserId(client);
	g_esPlayer[client].g_iUserID2 = g_esPlayer[client].g_iUserID;

	SDKHook(client, SDKHook_OnTakeDamage, OnCombineTakeDamage);
	SDKHook(client, SDKHook_OnTakeDamage, OnFriendlyTakeDamage);
	SDKHook(client, SDKHook_OnTakeDamage, OnPlayerTakeDamage);
	SDKHook(client, SDKHook_OnTakeDamagePost, OnPlayerTakeDamagePost);
	SDKHook(client, SDKHook_OnTakeDamageAlive, OnPlayerTakeDamageAlive);
	SDKHook(client, SDKHook_OnTakeDamageAlivePost, OnPlayerTakeDamageAlivePost);
	SDKHook(client, SDKHook_TouchPost, OnDoorTouchPost);
	SDKHook(client, SDKHook_WeaponEquipPost, OnWeaponEquipPost);
	SDKHook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitchPost);

	vResetTank2(client);
	vCacheSettings(client);
	vResetCore(client);
}

public void OnClientPostAdminCheck(int client)
{
	if (bIsValidClient(client, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT))
	{
		vLoadConfigs(g_esGeneral.g_sSavePath, 3);
	}

	GetClientAuthId(client, AuthId_Steam2, g_esPlayer[client].g_sSteamID32, sizeof esPlayer::g_sSteamID32);
	GetClientAuthId(client, AuthId_Steam3, g_esPlayer[client].g_sSteam3ID, sizeof esPlayer::g_sSteam3ID);
}

public void OnClientDisconnect(int client)
{
	if (bIsTank(client) && !bIsValidClient(client, MT_CHECK_FAKECLIENT))
	{
		if (!bIsCustomTank(client))
		{
			g_esGeneral.g_iTankCount--;
		}

		vCalculateDeath(client, 0);
	}

	if (bIsValidClient(client))
	{
		vResetPlayerStatus(client);
	}
}

public void OnConfigsExecuted()
{
	g_esGeneral.g_iChosenType = 0;
	g_esGeneral.g_iRegularCount = 0;
	g_esGeneral.g_iTankCount = 0;

	vDefaultConVarSettings();
	vLoadConfigs(g_esGeneral.g_sSavePath, 1);
	vSetupConfigs();
	vPluginStatus();
	vResetTimers();

	CreateTimer(0.1, tTimerRefreshRewards, .flags = TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
	CreateTimer(g_esGeneral.g_flConfigDelay, tTimerReloadConfigs, .flags = TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
	CreateTimer(1.0, tTimerRegenerateAmmo, .flags = TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
	CreateTimer(1.0, tTimerRegenerateHealth, .flags = TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
}

public void OnMapEnd()
{
	vResetPlugin();
	vToggleLogging(0);

	RemoveNormalSoundHook(FallSoundHook);
	RemoveNormalSoundHook(RockSoundHook);
	RemoveNormalSoundHook(VoiceSoundHook);
}

public void OnPluginEnd()
{
	vRemoveCommandListeners();
	vMultiTargetFilters(false);
	vClearSectionList();
	vRemovePermanentPatches();
	vTogglePlugin(false);

	if (g_esGeneral.g_alFilePaths != null)
	{
		g_esGeneral.g_alFilePaths.Clear();

		delete g_esGeneral.g_alFilePaths;
	}

	for (int iTank = 1; iTank <= MaxClients; iTank++)
	{
		if (bIsTank(iTank, MT_CHECK_INGAME|MT_CHECK_ALIVE))
		{
			vResetTank(iTank);
		}
	}

	Call_StartForward(g_esGeneral.g_gfPluginEndForward);
	Call_Finish();
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (g_esGeneral.g_bPluginEnabled && bIsValidEntity(entity))
	{
		g_esGeneral.g_bWitchKilled[entity] = false;
		g_esGeneral.g_iTeamID[entity] = 0;
		g_esGeneral.g_iTeamID2[entity] = 0;

		if (StrEqual(classname, "tank_rock"))
		{
			RequestFrame(vRockThrowFrame, EntIndexToEntRef(entity));
		}
		else if (StrEqual(classname, "infected") || StrEqual(classname, "witch"))
		{
			SDKHook(entity, SDKHook_SpawnPost, OnInfectedSpawnPost);
		}
		else if (StrEqual(classname, "inferno") || StrEqual(classname, "pipe_bomb_projectile") || (g_bSecondGame && (StrEqual(classname, "fire_cracker_blast") || StrEqual(classname, "grenade_launcher_projectile"))))
		{
			SDKHook(entity, SDKHook_SpawnPost, OnEffectSpawnPost);
		}
		else if (StrEqual(classname, "physics_prop") || StrEqual(classname, "prop_physics"))
		{
			SDKHook(entity, SDKHook_SpawnPost, OnPropSpawnPost);
		}
		else if (StrEqual(classname, "prop_fuel_barrel"))
		{
			SDKHook(entity, SDKHook_OnTakeDamage, OnPropTakeDamage);
		}
	}
}

public void OnEntityDestroyed(int entity)
{
	if (g_esGeneral.g_bPluginEnabled && bIsValidEntity(entity))
	{
		char sClassname[32];
		GetEntityClassname(entity, sClassname, sizeof sClassname);
		if (StrEqual(sClassname, "infected") || StrEqual(sClassname, "witch"))
		{
			SDKUnhook(entity, SDKHook_OnTakeDamage, OnInfectedTakeDamage);
			SDKUnhook(entity, SDKHook_OnTakeDamage, OnPlayerTakeDamage);
			SDKUnhook(entity, SDKHook_OnTakeDamagePost, OnPlayerTakeDamagePost);
		}
	}
}

public void OnGameFrame()
{
	if (g_esGeneral.g_bPluginEnabled)
	{
		bool bHuman = false;
		char sHealthBar[51], sHumanTag[128], sSet[2][2], sTankName[33];
		float flPercentage = 0.0;
		int iTarget = 0, iHealth = 0, iMaxHealth = 0, iTotalHealth = 0;
		for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
		{
			if (bIsValidClient(iPlayer, MT_CHECK_INGAME|MT_CHECK_FAKECLIENT))
			{
				iTarget = GetClientAimTarget(iPlayer);
				if (bIsTank(iTarget))
				{
					if (bIsTankIdle(iTarget, 1) && bIsSurvivor(iPlayer))
					{
						continue;
					}

					sHealthBar[0] = '\0';
					iHealth = bIsPlayerIncapacitated(iTarget) ? 0 : GetEntProp(iTarget, Prop_Data, "m_iHealth");
					iMaxHealth = GetEntProp(iTarget, Prop_Data, "m_iMaxHealth");
					iTotalHealth = (iHealth > iMaxHealth) ? iHealth : iMaxHealth;
					flPercentage = ((float(iHealth) / float(iTotalHealth)) * 100.0);

					ReplaceString(g_esCache[iTarget].g_sHealthCharacters, sizeof esCache::g_sHealthCharacters, " ", "");
					ExplodeString(g_esCache[iTarget].g_sHealthCharacters, ",", sSet, sizeof sSet, sizeof sSet[]);

					for (int iCount = 0; iCount < (float(iHealth) / float(iTotalHealth)) * ((sizeof sHealthBar) - 1) && iCount < ((sizeof sHealthBar) - 1); iCount++)
					{
						StrCat(sHealthBar, sizeof sHealthBar, sSet[0]);
					}

					for (int iCount = 0; iCount < ((sizeof sHealthBar) - 1); iCount++)
					{
						StrCat(sHealthBar, sizeof sHealthBar, sSet[1]);
					}

					bHuman = bIsValidClient(iTarget, MT_CHECK_FAKECLIENT);
					FormatEx(sHumanTag, sizeof sHumanTag, "%T", "HumanTag", iPlayer);
					vGetTranslatedName(sTankName, sizeof sTankName, iTarget);

					switch (g_esCache[iTarget].g_iDisplayHealthType)
					{
						case 1:
						{
							switch (g_esCache[iTarget].g_iDisplayHealth)
							{
								case 1: PrintHintText(iPlayer, "%t %s", sTankName, (bHuman ? sHumanTag : ""));
								case 2: PrintHintText(iPlayer, "%i HP", iHealth);
								case 3: PrintHintText(iPlayer, "%i/%i HP (%.0f%s)", iHealth, iTotalHealth, flPercentage, "%%");
								case 4: PrintHintText(iPlayer, "HP: |-<%s>-|", sHealthBar);
								case 5: PrintHintText(iPlayer, "%t %s (%i HP)", sTankName, (bHuman ? sHumanTag : ""), iHealth);
								case 6: PrintHintText(iPlayer, "%t %s [%i/%i HP (%.0f%s)]", sTankName, (bHuman ? sHumanTag : ""), iHealth, iTotalHealth, flPercentage, "%%");
								case 7: PrintHintText(iPlayer, "%t %s\nHP: |-<%s>-|", sTankName, (bHuman ? sHumanTag : ""), sHealthBar);
								case 8: PrintHintText(iPlayer, "%i HP\nHP: |-<%s>-|", iHealth, sHealthBar);
								case 9: PrintHintText(iPlayer, "%i/%i HP (%.0f%s)\nHP: |-<%s>-|", iHealth, iTotalHealth, flPercentage, "%%", sHealthBar);
								case 10: PrintHintText(iPlayer, "%t %s (%i HP)\nHP: |-<%s>-|", sTankName, (bHuman ? sHumanTag : ""), iHealth, sHealthBar);
								case 11: PrintHintText(iPlayer, "%t %s [%i/%i HP (%.0f%s)]\nHP: |-<%s>-|", sTankName, (bHuman ? sHumanTag : ""), iHealth, iTotalHealth, flPercentage, "%%", sHealthBar);
							}
						}
						case 2:
						{
							switch (g_esCache[iTarget].g_iDisplayHealth)
							{
								case 1: PrintCenterText(iPlayer, "%t %s", sTankName, (bHuman ? sHumanTag : ""));
								case 2: PrintCenterText(iPlayer, "%i HP", iHealth);
								case 3: PrintCenterText(iPlayer, "%i/%i HP (%.0f%s)", iHealth, iTotalHealth, flPercentage, "%%");
								case 4: PrintCenterText(iPlayer, "HP: |-<%s>-|", sHealthBar);
								case 5: PrintCenterText(iPlayer, "%t %s (%i HP)", sTankName, (bHuman ? sHumanTag : ""), iHealth);
								case 6: PrintCenterText(iPlayer, "%t %s [%i/%i HP (%.0f%s)]", sTankName, (bHuman ? sHumanTag : ""), iHealth, iTotalHealth, flPercentage, "%%");
								case 7: PrintCenterText(iPlayer, "%t %s\nHP: |-<%s>-|", sTankName, (bHuman ? sHumanTag : ""), sHealthBar);
								case 8: PrintCenterText(iPlayer, "%i HP\nHP: |-<%s>-|", iHealth, sHealthBar);
								case 9: PrintCenterText(iPlayer, "%i/%i HP (%.0f%s)\nHP: |-<%s>-|", iHealth, iTotalHealth, flPercentage, "%%", sHealthBar);
								case 10: PrintCenterText(iPlayer, "%t %s (%i HP)\nHP: |-<%s>-|", sTankName, (bHuman ? sHumanTag : ""), iHealth, sHealthBar);
								case 11: PrintCenterText(iPlayer, "%t %s [%i/%i HP (%.0f%s)]\nHP: |-<%s>-|", sTankName, (bHuman ? sHumanTag : ""), iHealth, iTotalHealth, flPercentage, "%%", sHealthBar);
							}
						}
					}
				}
			}
		}
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (!g_esGeneral.g_bPluginEnabled || !bIsValidClient(client))
	{
		return Plugin_Continue;
	}

	if (bIsSurvivor(client, MT_CHECK_INDEX|MT_CHECK_INGAME))
	{
		if (bIsValidClient(client, MT_CHECK_ALIVE))
		{
			bool bDeveloper = bIsDeveloper(client, 5), bDeveloper2 = bIsDeveloper(client, 6);
			if ((bDeveloper || bDeveloper2 || (g_esPlayer[client].g_iRewardTypes & MT_REWARD_SPEEDBOOST)) && (buttons & IN_JUMP))
			{
				if (bIsEntityGrounded(client) && !bIsSurvivorDisabled(client) && !bIsSurvivorCaught(client))
				{
					if (bDeveloper || bDeveloper2 || g_esPlayer[client].g_iBunnyHop == 1)
					{
						float flHeight = (bDeveloper && g_esDeveloper[client].g_flDevJumpHeight > g_esPlayer[client].g_flJumpHeight) ? g_esDeveloper[client].g_flDevJumpHeight : g_esPlayer[client].g_flJumpHeight;
						flHeight = (!bDeveloper && bDeveloper2 && flHeight <= 0.0) ? MT_JUMP_DEFAULTHEIGHT : flHeight;
						if (flHeight > 0.0)
						{
							vPushPlayer(client, {-90.0, 0.0, 0.0}, ((flHeight + 100.0) * 2.0));
						}

						float flAngles[3];
						GetClientEyeAngles(client, flAngles);
						flAngles[0] = 0.0;

						if (buttons & IN_BACK)
						{
							flAngles[1] += 180.0;
						}

						if (buttons & IN_MOVELEFT)
						{
							flAngles[1] += 90.0;
						}

						if (buttons & IN_MOVERIGHT)
						{
							flAngles[1] += -90.0;
						}

						vPushPlayer(client, flAngles, MT_JUMP_FORWARDBOOST);
					}
				}

				if (bDeveloper)
				{
					vReviveSurvivor(client);
					vSaveCaughtSurvivor(client);
				}
			}

			if ((bDeveloper || (g_esPlayer[client].g_iRewardTypes & MT_REWARD_SPEEDBOOST)) && g_esPlayer[client].g_iMidairDashesCount > 0)
			{
				if (!(buttons & IN_JUMP) && !g_esPlayer[client].g_bReleasedJump)
				{
					g_esPlayer[client].g_bReleasedJump = true;
				}

				if (bIsEntityGrounded(client))
				{
					g_esPlayer[client].g_iMidairDashesCount = 0;
				}
			}

			if ((bDeveloper2 || ((g_esPlayer[client].g_iRewardTypes & MT_REWARD_ATTACKBOOST) && g_esPlayer[client].g_iShovePenalty == 1)) && (buttons & IN_ATTACK2))
			{
				SetEntProp(client, Prop_Send, "m_iShovePenalty", 0, 1);
			}

			if (bIsDeveloper(client, 7) || (g_esPlayer[client].g_iRewardTypes & MT_REWARD_INFAMMO))
			{
				vRefillGunAmmo(client, true);
			}

			if (!bIsEntityGrounded(client))
			{
				float flVelocity[3];
				GetEntPropVector(client, Prop_Data, "m_vecVelocity", flVelocity);
				if (flVelocity[2] < 0.0)
				{
					if (!g_esPlayer[client].g_bFallTracked)
					{
						float flOrigin[3];
						GetEntPropVector(client, Prop_Data, "m_vecOrigin", flOrigin);
						g_esPlayer[client].g_flPreFallZ = flOrigin[2];
						g_esPlayer[client].g_bFallTracked = true;

						return Plugin_Continue;
					}
				}
				else if (g_esPlayer[client].g_bFalling || g_esPlayer[client].g_bFallTracked)
				{
					g_esPlayer[client].g_bFalling = false;
					g_esPlayer[client].g_bFallTracked = false;
					g_esPlayer[client].g_flPreFallZ = 0.0;
				}
			}
			else if (g_esPlayer[client].g_bFalling || g_esPlayer[client].g_bFallTracked)
			{
				g_esPlayer[client].g_bFalling = false;
				g_esPlayer[client].g_bFallTracked = false;
				g_esPlayer[client].g_flPreFallZ = 0.0;
			}
		}
		else if (bIsDeveloper(client, 10) && (buttons & IN_JUMP))
		{
			RequestFrame(vRespawnFrame, GetClientUserId(client));
		}
	}
	else if (bIsTank(client))
	{
		if (bIsTankSupported(client, MT_CHECK_FAKECLIENT))
		{
			int iButton = 0;
			for (int iBit = 0; iBit < 26; iBit++)
			{
				iButton = (1 << iBit);
				if (buttons & iButton)
				{
					if (!(g_esPlayer[client].g_iLastButtons & iButton))
					{
						Call_StartForward(g_esGeneral.g_gfButtonPressedForward);
						Call_PushCell(client);
						Call_PushCell(iButton);
						Call_Finish();
					}
				}
				else if (g_esPlayer[client].g_iLastButtons & iButton)
				{
					Call_StartForward(g_esGeneral.g_gfButtonReleasedForward);
					Call_PushCell(client);
					Call_PushCell(iButton);
					Call_Finish();
				}
			}

			g_esPlayer[client].g_iLastButtons = buttons;
		}

		if ((buttons & IN_ATTACK) && MT_GetRandomFloat(0.1, 100.0) <= g_esCache[client].g_flPunchThrow)
		{
			buttons |= IN_ATTACK2;

			return Plugin_Changed;
		}
	}

	return Plugin_Continue;
}

/**
 * Plugin status functions & callbacks
 **/

void vInitialReset(int client)
{
	g_esPlayer[client].g_iHudPanelLevel = 0;
	g_esPlayer[client].g_iHudPanelPages = 0;
	g_esPlayer[client].g_iLadyKillerCount = 0;
	g_esPlayer[client].g_iLadyKillerLimit = 0;
	g_esPlayer[client].g_iPersonalType = 0;
}

void vLateLoad()
{
	if (g_bLateLoad)
	{
#if defined _adminmenu_included
		TopMenu tmAdminMenu = null;

		if (LibraryExists("adminmenu") && ((tmAdminMenu = GetAdminTopMenu()) != null))
		{
			OnAdminMenuReady(tmAdminMenu);
		}
#endif
		for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
		{
			if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
			{
				OnClientPutInServer(iPlayer);
				OnClientPostAdminCheck(iPlayer);
#if defined _clientprefs_included
				if (bIsValidClient(iPlayer, MT_CHECK_FAKECLIENT) && AreClientCookiesCached(iPlayer))
				{
					OnClientCookiesCached(iPlayer);
				}
#endif
				if (bIsTank(iPlayer, MT_CHECK_ALIVE))
				{
					SDKHook(iPlayer, SDKHook_PostThinkPost, OnTankPostThinkPost);
				}
			}
		}

		int iEntity = -1;
		while ((iEntity = FindEntityByClassname(iEntity, "infected")) != INVALID_ENT_REFERENCE)
		{
			SDKHook(iEntity, SDKHook_OnTakeDamage, OnInfectedTakeDamage);
			SDKHook(iEntity, SDKHook_OnTakeDamage, OnPlayerTakeDamage);
			SDKHook(iEntity, SDKHook_OnTakeDamagePost, OnPlayerTakeDamagePost);
		}

		iEntity = -1;
		while ((iEntity = FindEntityByClassname(iEntity, "witch")) != INVALID_ENT_REFERENCE)
		{
			SDKHook(iEntity, SDKHook_OnTakeDamage, OnInfectedTakeDamage);
			SDKHook(iEntity, SDKHook_OnTakeDamage, OnPlayerTakeDamage);
			SDKHook(iEntity, SDKHook_OnTakeDamagePost, OnPlayerTakeDamagePost);
		}

		iEntity = -1;
		char sModel[64];
		while ((iEntity = FindEntityByClassname(iEntity, "prop_physics")) != INVALID_ENT_REFERENCE)
		{
			GetEntPropString(iEntity, Prop_Data, "m_ModelName", sModel, sizeof sModel);
			if (StrEqual(sModel, MODEL_OXYGENTANK) || StrEqual(sModel, MODEL_PROPANETANK) || StrEqual(sModel, MODEL_GASCAN) || (g_bSecondGame && StrEqual(sModel, MODEL_FIREWORKCRATE)))
			{
				SDKHook(iEntity, SDKHook_OnTakeDamage, OnPropTakeDamage);
			}
		}

		g_bLateLoad = false;
	}
}

void vPluginStatus()
{
	bool bPluginAllowed = bIsPluginEnabled();
	if (!g_esGeneral.g_bPluginEnabled && bPluginAllowed)
	{
		vTogglePlugin(bPluginAllowed);

		if (bIsCompetitiveModeRound(0))
		{
			g_esGeneral.g_alCompTypes = new ArrayList();
		}
	}
	else if (g_esGeneral.g_bPluginEnabled && !bPluginAllowed)
	{
		vTogglePlugin(bPluginAllowed);
	}
}

void vResetCore(int client)
{
	g_esPlayer[client].g_bAdminMenu = false;
	g_esPlayer[client].g_bDied = false;
	g_esPlayer[client].g_bIgnoreCmd = false;
	g_esPlayer[client].g_bInitialRound = g_esGeneral.g_bNextRound;
	g_esPlayer[client].g_bLastLife = false;
	g_esPlayer[client].g_bStasis = false;
	g_esPlayer[client].g_bThirdPerson = false;
#if defined _ThirdPersonShoulder_Detect_included
	g_esPlayer[client].g_bThirdPerson2 = false;
#endif
	g_esPlayer[client].g_iLastButtons = 0;
	g_esPlayer[client].g_iMaxClip[0] = 0;
	g_esPlayer[client].g_iMaxClip[1] = 0;
	g_esPlayer[client].g_iReviveCount = 0;

	vResetTankDamage(client);

	delete g_esPlayer[client].g_hHudTimer;
}

void vResetPlugin()
{
	g_esGeneral.g_iPlayerCount[1] = iGetHumanCount();
	g_esGeneral.g_iPlayerCount[2] = iGetHumanCount(true);

	vResetRound();
	vClearAbilityList();
	vClearColorKeysList();
	vClearCompTypesList();
	vClearPluginList();
}

void vResetRound()
{
	g_esGeneral.g_bFinaleEnded = false;
	g_esGeneral.g_bForceSpawned = false;
	g_esGeneral.g_bUsedParser = false;
	g_esGeneral.g_iChosenType = 0;
	g_esGeneral.g_iParserViewer = 0;
	g_esGeneral.g_iRegularCount = 0;
	g_esGeneral.g_iSurvivalBlock = 0;
	g_esGeneral.g_iTankCount = 0;
	g_esGeneral.g_iTankWave = 0;

	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
		{
			vResetPlayerStatus(iPlayer);
		}
	}

	delete g_esGeneral.g_hRegularWavesTimer;
	delete g_esGeneral.g_hSurvivalTimer;
	delete g_esGeneral.g_hTankWaveTimer;
}

void vTogglePlugin(bool toggle)
{
	g_esGeneral.g_bPluginEnabled = toggle;

	vHookEvents(toggle);
	vToggleDetours(toggle);
}

bool bIsPluginEnabled()
{
	if (!g_esGeneral.g_cvMTPluginEnabled.BoolValue || g_esGeneral.g_iPluginEnabled == 0 || (!g_bDedicated && !g_esGeneral.g_cvMTListenSupport.BoolValue && g_esGeneral.g_iListenSupport == 0) || g_esGeneral.g_cvMTGameMode == null)
	{
		return false;
	}

	g_esGeneral.g_iCurrentMode = 0;

	if ((g_esGeneral.g_hSDKIsCoopMode != null && SDKCall(g_esGeneral.g_hSDKIsCoopMode)) || (g_bSecondGame && ((g_esGeneral.g_hSDKIsRealismMode != null && SDKCall(g_esGeneral.g_hSDKIsRealismMode)) || (g_esGeneral.g_hSDKHasConfigurableDifficultySetting != null && SDKCall(g_esGeneral.g_hSDKHasConfigurableDifficultySetting)))))
	{
		g_esGeneral.g_iCurrentMode = 1;
	}
	else if (g_esGeneral.g_hSDKIsVersusMode != null && SDKCall(g_esGeneral.g_hSDKIsVersusMode))
	{
		g_esGeneral.g_iCurrentMode = 2;
	}
	else if (g_esGeneral.g_hSDKIsSurvivalMode != null && SDKCall(g_esGeneral.g_hSDKIsSurvivalMode))
	{
		g_esGeneral.g_iCurrentMode = 4;
	}
	else if (g_bSecondGame && g_esGeneral.g_hSDKIsScavengeMode != null && SDKCall(g_esGeneral.g_hSDKIsScavengeMode))
	{
		g_esGeneral.g_iCurrentMode = 8;
	}

	int iMode = (g_esGeneral.g_iGameModeTypes == 0) ? g_esGeneral.g_cvMTGameModeTypes.IntValue : g_esGeneral.g_iGameModeTypes;
	if (iMode != 0 && (g_esGeneral.g_iCurrentMode == 0 || !(iMode & g_esGeneral.g_iCurrentMode)))
	{
		return false;
	}

	char sFixed[32], sGameMode[32], sGameModes[513], sGameModesCvar[513], sList[513], sListCvar[513];
	g_esGeneral.g_cvMTGameMode.GetString(sGameMode, sizeof sGameMode);
	FormatEx(sFixed, sizeof sFixed, ",%s,", sGameMode);

	strcopy(sGameModes, sizeof sGameModes, g_esGeneral.g_sEnabledGameModes);
	g_esGeneral.g_cvMTEnabledGameModes.GetString(sGameModesCvar, sizeof sGameModesCvar);
	if (sGameModes[0] != '\0' || sGameModesCvar[0] != '\0')
	{
		if (sGameModes[0] != '\0')
		{
			FormatEx(sList, sizeof sList, ",%s,", sGameModes);
		}

		if (sGameModesCvar[0] != '\0')
		{
			FormatEx(sListCvar, sizeof sListCvar, ",%s,", sGameModesCvar);
		}

		if ((sList[0] != '\0' && StrContains(sList, sFixed, false) == -1) && (sListCvar[0] != '\0' && StrContains(sListCvar, sFixed, false) == -1))
		{
			return false;
		}
	}

	strcopy(sGameModes, sizeof sGameModes, g_esGeneral.g_sDisabledGameModes);
	g_esGeneral.g_cvMTDisabledGameModes.GetString(sGameModesCvar, sizeof sGameModesCvar);
	if (sGameModes[0] != '\0' || sGameModesCvar[0] != '\0')
	{
		if (sGameModes[0] != '\0')
		{
			FormatEx(sList, sizeof sList, ",%s,", sGameModes);
		}

		if (sGameModesCvar[0] != '\0')
		{
			FormatEx(sListCvar, sizeof sListCvar, ",%s,", sGameModesCvar);
		}

		if ((sList[0] != '\0' && StrContains(sList, sFixed, false) != -1) || (sListCvar[0] != '\0' && StrContains(sListCvar, sFixed, false) != -1))
		{
			return false;
		}
	}

	return true;
}

/**
 * Mutant Tanks Library
 **/

void vRegisterForwards()
{
	g_esGeneral.g_gfAbilityActivatedForward = new GlobalForward("MT_OnAbilityActivated", ET_Ignore, Param_Cell);
	g_esGeneral.g_gfAbilityCheckForward = new GlobalForward("MT_OnAbilityCheck", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	g_esGeneral.g_gfButtonPressedForward = new GlobalForward("MT_OnButtonPressed", ET_Ignore, Param_Cell, Param_Cell);
	g_esGeneral.g_gfButtonReleasedForward = new GlobalForward("MT_OnButtonReleased", ET_Ignore, Param_Cell, Param_Cell);
	g_esGeneral.g_gfChangeTypeForward = new GlobalForward("MT_OnChangeType", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	g_esGeneral.g_gfCombineAbilitiesForward = new GlobalForward("MT_OnCombineAbilities", ET_Ignore, Param_Cell, Param_Cell, Param_Float, Param_String, Param_Cell, Param_Cell, Param_String);
	g_esGeneral.g_gfConfigsLoadForward = new GlobalForward("MT_OnConfigsLoad", ET_Ignore, Param_Cell);
	g_esGeneral.g_gfConfigsLoadedForward = new GlobalForward("MT_OnConfigsLoaded", ET_Ignore, Param_String, Param_String, Param_String, Param_Cell, Param_Cell, Param_Cell);
	g_esGeneral.g_gfCopyStatsForward = new GlobalForward("MT_OnCopyStats", ET_Ignore, Param_Cell, Param_Cell);
	g_esGeneral.g_gfDisplayMenuForward = new GlobalForward("MT_OnDisplayMenu", ET_Ignore, Param_Cell);
	g_esGeneral.g_gfEventFiredForward = new GlobalForward("MT_OnEventFired", ET_Ignore, Param_Cell, Param_String, Param_Cell);
	g_esGeneral.g_gfFatalFallingForward = new GlobalForward("MT_OnFatalFalling", ET_Event, Param_Cell);
	g_esGeneral.g_gfHookEventForward = new GlobalForward("MT_OnHookEvent", ET_Ignore, Param_Cell);
	g_esGeneral.g_gfLogMessageForward = new GlobalForward("MT_OnLogMessage", ET_Event, Param_Cell, Param_String);
	g_esGeneral.g_gfMenuItemDisplayedForward = new GlobalForward("MT_OnMenuItemDisplayed", ET_Ignore, Param_Cell, Param_String, Param_String, Param_Cell);
	g_esGeneral.g_gfMenuItemSelectedForward = new GlobalForward("MT_OnMenuItemSelected", ET_Ignore, Param_Cell, Param_String);
	g_esGeneral.g_gfPlayerEventKilledForward = new GlobalForward("MT_OnPlayerEventKilled", ET_Ignore, Param_Cell, Param_Cell);
	g_esGeneral.g_gfPlayerHitByVomitJarForward = new GlobalForward("MT_OnPlayerHitByVomitJar", ET_Event, Param_Cell, Param_Cell);
	g_esGeneral.g_gfPlayerShovedBySurvivorForward = new GlobalForward("MT_OnPlayerShovedBySurvivor", ET_Event, Param_Cell, Param_Cell, Param_Array);
	g_esGeneral.g_gfPluginCheckForward = new GlobalForward("MT_OnPluginCheck", ET_Ignore, Param_Cell);
	g_esGeneral.g_gfPluginEndForward = new GlobalForward("MT_OnPluginEnd", ET_Ignore);
	g_esGeneral.g_gfPostTankSpawnForward = new GlobalForward("MT_OnPostTankSpawn", ET_Ignore, Param_Cell);
	g_esGeneral.g_gfResetTimersForward = new GlobalForward("MT_OnResetTimers", ET_Ignore, Param_Cell, Param_Cell);
	g_esGeneral.g_gfRewardSurvivorForward = new GlobalForward("MT_OnRewardSurvivor", ET_Event, Param_Cell, Param_Cell, Param_CellByRef, Param_Cell, Param_FloatByRef, Param_Cell);
	g_esGeneral.g_gfRockBreakForward = new GlobalForward("MT_OnRockBreak", ET_Ignore, Param_Cell, Param_Cell);
	g_esGeneral.g_gfRockThrowForward = new GlobalForward("MT_OnRockThrow", ET_Ignore, Param_Cell, Param_Cell);
	g_esGeneral.g_gfSettingsCachedForward = new GlobalForward("MT_OnSettingsCached", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	g_esGeneral.g_gfTypeChosenForward = new GlobalForward("MT_OnTypeChosen", ET_Event, Param_CellByRef, Param_Cell);
#if defined _updater_included
	g_esGeneral.g_gfPluginUpdateForward = new GlobalForward("MT_OnPluginUpdate", ET_Ignore);
#endif
}

void vRegisterNatives()
{
	CreateNative("MT_CanTypeSpawn", aNative_CanTypeSpawn);
	CreateNative("MT_DeafenPlayer", aNative_DeafenPlayer);
	CreateNative("MT_DetonateTankRock", aNative_DetonateTankRock);
	CreateNative("MT_DoesSurvivorHaveRewardType", aNative_DoesSurvivorHaveRewardType);
	CreateNative("MT_DoesTypeRequireHumans", aNative_DoesTypeRequireHumans);
	CreateNative("MT_GetAccessFlags", aNative_GetAccessFlags);
	CreateNative("MT_GetCombinationSetting", aNative_GetCombinationSetting);
	CreateNative("MT_GetConfigColors", aNative_GetConfigColors);
	CreateNative("MT_GetCurrentFinaleWave", aNative_GetCurrentFinaleWave);
	CreateNative("MT_GetGlowRange", aNative_GetGlowRange);
	CreateNative("MT_GetGlowType", aNative_GetGlowType);
	CreateNative("MT_GetImmunityFlags", aNative_GetImmunityFlags);
	CreateNative("MT_GetMaxType", aNative_GetMaxType);
	CreateNative("MT_GetMinType", aNative_GetMinType);
	CreateNative("MT_GetPropColors", aNative_GetPropColors);
	CreateNative("MT_GetRunSpeed", aNative_GetRunSpeed);
	CreateNative("MT_GetScaledDamage", aNative_GetScaledDamage);
	CreateNative("MT_GetSpawnType", aNative_GetSpawnType);
	CreateNative("MT_GetTankColors", aNative_GetTankColors);
	CreateNative("MT_GetTankName", aNative_GetTankName);
	CreateNative("MT_GetTankType", aNative_GetTankType);
	CreateNative("MT_HasAdminAccess", aNative_HasAdminAccess);
	CreateNative("MT_HasChanceToSpawn", aNative_HasChanceToSpawn);
	CreateNative("MT_HideEntity", aNative_HideEntity);
	CreateNative("MT_IsAdminImmune", aNative_IsAdminImmune);
	CreateNative("MT_IsCorePluginEnabled", aNative_IsCorePluginEnabled);
	CreateNative("MT_IsCustomTankSupported", aNative_IsCustomTankSupported);
	CreateNative("MT_IsFinaleType", aNative_IsFinaleType);
	CreateNative("MT_IsGlowEnabled", aNative_IsGlowEnabled);
	CreateNative("MT_IsGlowFlashing", aNative_IsGlowFlashing);
	CreateNative("MT_IsNonFinaleType", aNative_IsNonFinaleType);
	CreateNative("MT_IsTankIdle", aNative_IsTankIdle);
	CreateNative("MT_IsTankSupported", aNative_IsTankSupported);
	CreateNative("MT_IsTypeEnabled", aNative_IsTypeEnabled);
	CreateNative("MT_LogMessage", aNative_LogMessage);
	CreateNative("MT_RespawnSurvivor", aNative_RespawnSurvivor);
	CreateNative("MT_SetTankType", aNative_SetTankType);
	CreateNative("MT_ShoveBySurvivor", aNative_ShoveBySurvivor);
	CreateNative("MT_SpawnTank", aNative_SpawnTank);
	CreateNative("MT_StaggerPlayer", aNative_StaggerPlayer);
	CreateNative("MT_TankMaxHealth", aNative_TankMaxHealth);
	CreateNative("MT_UnvomitPlayer", aNative_UnvomitPlayer);
	CreateNative("MT_VomitPlayer", aNative_VomitPlayer);
}

/**
 * Native callbacks
 **/

any aNative_CanTypeSpawn(Handle plugin, int numParams)
{
	int iType = iClamp(GetNativeCell(1), 1, MT_MAXTYPES);
	return (g_esGeneral.g_iSpawnEnabled == 1 || g_esTank[iType].g_iSpawnEnabled == 1) && bCanTypeSpawn(iType) && bIsRightGame(iType);
}

any aNative_DeafenPlayer(Handle plugin, int numParams)
{
	int iPlayer = GetNativeCell(1);
	if (bIsValidClient(iPlayer, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE) && g_esGeneral.g_hSDKDeafen != null)
	{
		SDKCall(g_esGeneral.g_hSDKDeafen, iPlayer, 1.0, 0.0, 0.01);
	}

	return 0;
}

any aNative_DetonateTankRock(Handle plugin, int numParams)
{
	int iRock = GetNativeCell(1);
	if (bIsValidEntity(iRock))
	{
		RequestFrame(vDetonateRockFrame, EntIndexToEntRef(iRock));
	}

	return 0;
}

any aNative_DoesSurvivorHaveRewardType(Handle plugin, int numParams)
{
	int iSurvivor = GetNativeCell(1), iType = GetNativeCell(2);
	if (bIsSurvivor(iSurvivor) && iType > 0)
	{
		if (iType & MT_REWARD_HEALTH)
		{
			return bIsDeveloper(iSurvivor, 6) || bIsDeveloper(iSurvivor, 7) || (g_esPlayer[iSurvivor].g_iRewardTypes & iType);
		}
		else if (iType & MT_REWARD_SPEEDBOOST)
		{
			return bIsDeveloper(iSurvivor, 5) || (g_esPlayer[iSurvivor].g_iRewardTypes & iType);
		}
		else if (iType & MT_REWARD_DAMAGEBOOST)
		{
			return bIsDeveloper(iSurvivor, 4) || (g_esPlayer[iSurvivor].g_iRewardTypes & iType);
		}
		else if (iType & MT_REWARD_ATTACKBOOST)
		{
			return bIsDeveloper(iSurvivor, 6) || (g_esPlayer[iSurvivor].g_iRewardTypes & iType);
		}
		else if (iType & MT_REWARD_AMMO)
		{
			return bIsDeveloper(iSurvivor, 4) || bIsDeveloper(iSurvivor, 6) || (g_esPlayer[iSurvivor].g_iRewardTypes & iType);
		}
		else if (iType & MT_REWARD_ITEM)
		{
			return !!(g_esPlayer[iSurvivor].g_iRewardTypes & iType);
		}
		else if (iType & MT_REWARD_GODMODE)
		{
			return bIsDeveloper(iSurvivor, 11) || (g_esPlayer[iSurvivor].g_iRewardTypes & iType);
		}
		else if (iType & MT_REWARD_REFILL)
		{
			return !!(g_esPlayer[iSurvivor].g_iRewardTypes & iType);
		}
		else if (iType & MT_REWARD_RESPAWN)
		{
			return bIsDeveloper(iSurvivor, 10) || (g_esPlayer[iSurvivor].g_iRewardTypes & iType);
		}
		else if (iType & MT_REWARD_INFAMMO)
		{
			return bIsDeveloper(iSurvivor, 7) || (g_esPlayer[iSurvivor].g_iRewardTypes & iType);
		}
	}

	return false;
}

any aNative_DoesTypeRequireHumans(Handle plugin, int numParams)
{
	int iType = iClamp(GetNativeCell(1), 1, MT_MAXTYPES);
	return bAreHumansRequired(iType);
}

any aNative_GetAccessFlags(Handle plugin, int numParams)
{
	int iMode = iClamp(GetNativeCell(1), 1, 4), iType = iClamp(GetNativeCell(2), 1, MT_MAXTYPES), iAdmin = GetNativeCell(3);

	switch (iMode)
	{
		case 1: return g_esGeneral.g_iAccessFlags;
		case 2: return g_esTank[iType].g_iAccessFlags;
		case 3: return bIsValidClient(iAdmin, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) ? g_esPlayer[iAdmin].g_iAccessFlags : 0;
		case 4: return bIsValidClient(iAdmin, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) ? g_esAdmin[iType].g_iAccessFlags[iAdmin] : 0;
	}

	return 0;
}

any aNative_GetCombinationSetting(Handle plugin, int numParams)
{
	int iTank = GetNativeCell(1), iType = iClamp(GetNativeCell(2), 1, 16), iPos = iClamp(GetNativeCell(3), 0, 9);
	if (bIsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME))
	{
		switch (iType)
		{
			case 1: return g_esCache[iTank].g_flComboChance[iPos];
			case 2: return float(g_esCache[iTank].g_iComboCooldown[iPos]);
			case 3: return g_esCache[iTank].g_flComboDamage[iPos];
			case 4: return g_esCache[iTank].g_flComboDelay[iPos];
			case 5: return g_esCache[iTank].g_flComboDuration[iPos];
			case 6: return g_esCache[iTank].g_flComboInterval[iPos];
			case 7: return g_esCache[iTank].g_flComboMinRadius[iPos];
			case 8: return g_esCache[iTank].g_flComboMaxRadius[iPos];
			case 9: return g_esCache[iTank].g_flComboRange[iPos];
			case 10: return g_esCache[iTank].g_flComboRangeChance[iPos];
			case 11: return float(g_esCache[iTank].g_iComboRangeCooldown[iPos]);
			case 12: return g_esCache[iTank].g_flComboDeathChance[iPos];
			case 13: return g_esCache[iTank].g_flComboDeathRange[iPos];
			case 14: return g_esCache[iTank].g_flComboRockChance[iPos];
			case 15: return float(g_esCache[iTank].g_iComboRockCooldown[iPos]);
			case 16: return g_esCache[iTank].g_flComboSpeed[iPos];
		}
	}

	return 0.0;
}

any aNative_GetConfigColors(Handle plugin, int numParams)
{
	int iSize = GetNativeCell(2);
	char[] sColor = new char[iSize], sValue = new char[iSize];
	GetNativeString(3, sColor, iSize);
	vGetConfigColors(sValue, iSize, sColor);
	SetNativeString(1, sValue, iSize);

	return 0;
}

any aNative_GetCurrentFinaleWave(Handle plugin, int numParams)
{
	return g_esGeneral.g_iTankWave;
}

any aNative_GetGlowRange(Handle plugin, int numParams)
{
	int iTank = GetNativeCell(1);
	bool bMode = GetNativeCell(2);
	if (bIsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME))
	{
		switch (bMode)
		{
			case true: return g_esCache[iTank].g_iGlowMaxRange;
			case false: return g_esCache[iTank].g_iGlowMinRange;
		}
	}

	return 0;
}

any aNative_GetGlowType(Handle plugin, int numParams)
{
	int iTank = GetNativeCell(1);
	return bIsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME) ? g_esCache[iTank].g_iGlowType : 0;
}

any aNative_GetImmunityFlags(Handle plugin, int numParams)
{
	int iMode = iClamp(GetNativeCell(1), 1, 4), iType = iClamp(GetNativeCell(2), 1, MT_MAXTYPES), iAdmin = GetNativeCell(3);

	switch (iMode)
	{
		case 1: return g_esGeneral.g_iImmunityFlags;
		case 2: return g_esTank[iType].g_iImmunityFlags;
		case 3: return bIsValidClient(iAdmin, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) ? g_esPlayer[iAdmin].g_iImmunityFlags : 0;
		case 4: return bIsValidClient(iAdmin, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) ? g_esAdmin[iType].g_iImmunityFlags[iAdmin] : 0;
	}

	return 0;
}

any aNative_GetMaxType(Handle plugin, int numParams)
{
	return g_esGeneral.g_iMaxType;
}

any aNative_GetMinType(Handle plugin, int numParams)
{
	return g_esGeneral.g_iMinType;
}

any aNative_GetPropColors(Handle plugin, int numParams)
{
	int iTank = GetNativeCell(1), iType = iClamp(GetNativeCell(2), 1, 8);
	if (bIsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME))
	{
		bool bRainbow[6] = {false, false, false, false, false, false};
		bRainbow[0] = StrEqual(g_esCache[iTank].g_sOzTankColor, "rainbow", false);
		bRainbow[1] = StrEqual(g_esCache[iTank].g_sFlameColor, "rainbow", false);
		bRainbow[2] = StrEqual(g_esCache[iTank].g_sRockColor, "rainbow", false);
		bRainbow[3] = StrEqual(g_esCache[iTank].g_sTireColor, "rainbow", false);
		bRainbow[4] = StrEqual(g_esCache[iTank].g_sPropTankColor, "rainbow", false);
		bRainbow[5] = StrEqual(g_esCache[iTank].g_sFlashlightColor, "rainbow", false);

		int iColor[4];
		for (int iPos = 0; iPos < (sizeof iColor); iPos++)
		{
			switch (iType)
			{
				case 1: iGetRandomColor(g_esCache[iTank].g_iLightColor[iPos]);
				case 2: iColor[iPos] = bRainbow[iType - 2] ? -2 : iGetRandomColor(g_esCache[iTank].g_iOzTankColor[iPos]);
				case 3: iColor[iPos] = bRainbow[iType - 2] ? -2 : iGetRandomColor(g_esCache[iTank].g_iFlameColor[iPos]);
				case 4: iColor[iPos] = bRainbow[iType - 2] ? -2 : iGetRandomColor(g_esCache[iTank].g_iRockColor[iPos]);
				case 5: iColor[iPos] = bRainbow[iType - 2] ? -2 : iGetRandomColor(g_esCache[iTank].g_iTireColor[iPos]);
				case 6: iColor[iPos] = bRainbow[iType - 2] ? -2 : iGetRandomColor(g_esCache[iTank].g_iPropTankColor[iPos]);
				case 7: iColor[iPos] = bRainbow[iType - 2] ? -2 : iGetRandomColor(g_esCache[iTank].g_iFlashlightColor[iPos]);
				case 8: iGetRandomColor(g_esCache[iTank].g_iCrownColor[iPos]);
			}

			SetNativeCellRef((iPos + 3), iColor[iPos]);
		}
	}

	return 0;
}

any aNative_GetRunSpeed(Handle plugin, int numParams)
{
	int iTank = GetNativeCell(1);
	if (bIsTank(iTank))
	{
		return (g_esCache[iTank].g_flRunSpeed > 0.0) ? g_esCache[iTank].g_flRunSpeed : 1.0;
	}

	return 0.0;
}

any aNative_GetScaledDamage(Handle plugin, int numParams)
{
	return flGetScaledDamage(GetNativeCell(1));
}

any aNative_GetSpawnType(Handle plugin, int numParams)
{
	int iTank = GetNativeCell(1);
	return (bIsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME) && !bIsTank(iTank, MT_CHECK_FAKECLIENT)) ? g_esCache[iTank].g_iSpawnType : 0;
}

any aNative_GetTankColors(Handle plugin, int numParams)
{
	int iTank = GetNativeCell(1), iType = iClamp(GetNativeCell(2), 1, 2);
	if (bIsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME))
	{
		bool bRainbow[2] = {false, false};
		bRainbow[0] = StrEqual(g_esCache[iTank].g_sSkinColor, "rainbow", false);
		bRainbow[1] = StrEqual(g_esCache[iTank].g_sGlowColor, "rainbow", false);

		int iColor[4];
		for (int iPos = 0; iPos < (sizeof iColor); iPos++)
		{
			switch (iType)
			{
				case 1: iColor[iPos] = bRainbow[iType - 1] ? -2 : iGetRandomColor(g_esCache[iTank].g_iSkinColor[iPos]);
				case 2:
				{
					if (iPos < (sizeof esCache::g_iGlowColor))
					{
						iColor[iPos] = bRainbow[iType - 1] ? -2 : iGetRandomColor(g_esCache[iTank].g_iGlowColor[iPos]);
					}
				}
			}

			SetNativeCellRef((iPos + 3), iColor[iPos]);
		}
	}

	return 0;
}

any aNative_GetTankName(Handle plugin, int numParams)
{
	int iTank = GetNativeCell(1);
	if (bIsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME))
	{
		char sTankName[33];
		vGetTranslatedName(sTankName, sizeof sTankName, iTank);
		SetNativeString(2, sTankName, sizeof sTankName);
	}

	return 0;
}

any aNative_GetTankType(Handle plugin, int numParams)
{
	int iTank = GetNativeCell(1);
	return bIsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME) ? g_esPlayer[iTank].g_iTankType : 0;
}

any aNative_HasAdminAccess(Handle plugin, int numParams)
{
	int iAdmin = GetNativeCell(1);
	return bIsTankSupported(iAdmin, MT_CHECK_INDEX|MT_CHECK_INGAME) && bHasCoreAdminAccess(iAdmin);
}

any aNative_HasChanceToSpawn(Handle plugin, int numParams)
{
	int iType = iClamp(GetNativeCell(1), 1, MT_MAXTYPES);
	return MT_GetRandomFloat(0.1, 100.0) <= g_esTank[iType].g_flTankChance;
}

any aNative_HideEntity(Handle plugin, int numParams)
{
	int iEntity = GetNativeCell(1);
	bool bMode = GetNativeCell(2);
	if (bIsValidEntity(iEntity))
	{
		switch (bMode)
		{
			case true: SDKHook(iEntity, SDKHook_SetTransmit, OnPropSetTransmit);
			case false: SDKUnhook(iEntity, SDKHook_SetTransmit, OnPropSetTransmit);
		}
	}

	return 0;
}

any aNative_IsAdminImmune(Handle plugin, int numParams)
{
	int iSurvivor = GetNativeCell(1), iTank = GetNativeCell(2);
	return bIsHumanSurvivor(iSurvivor) && bIsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME) && bIsCoreAdminImmune(iSurvivor, iTank);
}

any aNative_IsCorePluginEnabled(Handle plugin, int numParams)
{
	return g_esGeneral.g_bPluginEnabled;
}

any aNative_IsCustomTankSupported(Handle plugin, int numParams)
{
	int iTank = GetNativeCell(1);
	return bIsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME) && bIsCustomTankSupported(iTank);
}

any aNative_IsFinaleType(Handle plugin, int numParams)
{
	int iType = iClamp(GetNativeCell(1), 1, MT_MAXTYPES);
	return g_esTank[iType].g_iFinaleTank == 1;
}

any aNative_IsGlowEnabled(Handle plugin, int numParams)
{
	int iTank = GetNativeCell(1);
	return bIsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME) && g_esCache[iTank].g_iGlowEnabled == 1;
}

any aNative_IsGlowFlashing(Handle plugin, int numParams)
{
	int iTank = GetNativeCell(1);
	return bIsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME) && g_esCache[iTank].g_iGlowFlashing == 1;
}

any aNative_IsNonFinaleType(Handle plugin, int numParams)
{
	int iType = iClamp(GetNativeCell(1), 1, MT_MAXTYPES);
	return g_esTank[iType].g_iFinaleTank == 2;
}

any aNative_IsTankIdle(Handle plugin, int numParams)
{
	int iTank = GetNativeCell(1), iType = iClamp(GetNativeCell(2), 0, 2);
	return bIsTank(iTank) && bIsTankIdle(iTank, iType);
}

any aNative_IsTankSupported(Handle plugin, int numParams)
{
	int iTank = GetNativeCell(1);
	return bIsTank(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME) && bIsTankSupported(iTank, GetNativeCell(2));
}

any aNative_IsTypeEnabled(Handle plugin, int numParams)
{
	int iType = iClamp(GetNativeCell(1), 1, MT_MAXTYPES);
	return bIsTankEnabled(iType) && bIsTypeAvailable(iType);
}

any aNative_LogMessage(Handle plugin, int numParams)
{
	int iType = GetNativeCell(1);
	if (g_esGeneral.g_iLogMessages > 0 && iType > 0 && (g_esGeneral.g_iLogMessages & iType))
	{
		char sBuffer[PLATFORM_MAX_PATH];
		int iSize = 0, iResult = FormatNativeString(0, 2, 3, sizeof sBuffer, iSize, sBuffer);
		if (iResult == SP_ERROR_NONE)
		{
			vLogMessage(iType, _, sBuffer);
		}
	}

	return 0;
}

any aNative_RespawnSurvivor(Handle plugin, int numParams)
{
	int iSurvivor = GetNativeCell(1);
	if (bIsSurvivor(iSurvivor, MT_CHECK_INDEX|MT_CHECK_INGAME) && g_esGeneral.g_hSDKRoundRespawn != null)
	{
		vRespawnSurvivor(iSurvivor);
	}

	return 0;
}

any aNative_SetTankType(Handle plugin, int numParams)
{
	int iTank = GetNativeCell(1), iType = iClamp(GetNativeCell(2), 1, MT_MAXTYPES);
	bool bMode = GetNativeCell(3);
	if (bIsTank(iTank))
	{
		switch (bMode)
		{
			case true:
			{
				vSetTankColor(iTank, iType, .revert = (g_esPlayer[iTank].g_iTankType == iType));
				vTankSpawn(iTank, 5);
			}
			case false:
			{
				vResetTank3(iTank);
				vChangeTypeForward(iTank, g_esPlayer[iTank].g_iTankType, iType, (g_esPlayer[iTank].g_iTankType == iType));

				g_esPlayer[iTank].g_iOldTankType = g_esPlayer[iTank].g_iTankType;
				g_esPlayer[iTank].g_iTankType = iType;

				vCacheSettings(iTank);
			}
		}
	}

	return 0;
}

any aNative_ShoveBySurvivor(Handle plugin, int numParams)
{
	int iSpecial = GetNativeCell(1), iSurvivor = GetNativeCell(2);
	float flDirection[3];
	GetNativeArray(3, flDirection, sizeof flDirection);
	if (bIsInfected(iSpecial) && bIsSurvivor(iSurvivor) && g_esGeneral.g_hSDKShovedBySurvivor != null)
	{
		SDKCall(g_esGeneral.g_hSDKShovedBySurvivor, iSpecial, iSurvivor, flDirection);
	}

	return 0;
}

any aNative_SpawnTank(Handle plugin, int numParams)
{
	int iTank = GetNativeCell(1), iType = iClamp(GetNativeCell(2), 1, MT_MAXTYPES);
	if (bIsTank(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME))
	{
		vQueueTank(iTank, g_esTank[iType].g_iRecordedType[0], .log = false);
	}

	return 0;
}

any aNative_StaggerPlayer(Handle plugin, int numParams)
{
	int iPlayer = GetNativeCell(1), iPusher = GetNativeCell(2);
	float flDirection[3];
	GetNativeArray(3, flDirection, sizeof flDirection);
	if (bIsValidClient(iPlayer, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE) && bIsValidClient(iPusher, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE) && g_esGeneral.g_hSDKStagger != null)
	{
		if (IsNativeParamNullVector(3))
		{
			GetClientAbsOrigin(iPusher, flDirection);
		}

		SDKCall(g_esGeneral.g_hSDKStagger, iPlayer, iPusher, flDirection);
	}

	return 0;
}

any aNative_TankMaxHealth(Handle plugin, int numParams)
{
	int iTank = GetNativeCell(1), iMode = iClamp(GetNativeCell(2), 1, 3), iNewHealth = GetNativeCell(3);
	if (bIsTank(iTank))
	{
		switch (iMode)
		{
			case 1: return g_esPlayer[iTank].g_iTankHealth;
			case 2: return GetEntProp(iTank, Prop_Data, "m_iMaxHealth");
			case 3: g_esPlayer[iTank].g_iTankHealth = iNewHealth;
			case 4:
			{
				SetEntProp(iTank, Prop_Data, "m_iMaxHealth", iNewHealth);

				g_esPlayer[iTank].g_iTankHealth = GetEntProp(iTank, Prop_Data, "m_iMaxHealth");
			}
		}
	}

	return 0;
}

any aNative_UnvomitPlayer(Handle plugin, int numParams)
{
	int iPlayer = GetNativeCell(1);
	if (bIsValidClient(iPlayer, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE) && GetClientTeam(iPlayer) > 1 && g_esPlayer[iPlayer].g_bVomited)
	{
		vUnvomitPlayer(iPlayer);
	}

	return 0;
}

any aNative_VomitPlayer(Handle plugin, int numParams)
{
	int iPlayer = GetNativeCell(1), iBoomer = GetNativeCell(2);
	if (bIsValidClient(iPlayer, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE) && GetClientTeam(iPlayer) > 1 && bIsValidClient(iBoomer, MT_CHECK_INDEX|MT_CHECK_INGAME))
	{
		if (g_esGeneral.g_hSDKVomitedUpon != null)
		{
			switch (g_bSecondGame)
			{
				case true: SDKCall(g_esGeneral.g_hSDKVomitedUpon, iPlayer, iBoomer, false);
				case false: SDKCall(g_esGeneral.g_hSDKVomitedUpon, iPlayer, iBoomer, false, false);
			}
		}
	}

	return 0;
}

/**
 * Client cookies functions & callbacks
 **/

#if defined _clientprefs_included
public void OnClientCookiesCached(int client)
{
	char sColor[16];
	for (int iPos = 0; iPos < (sizeof esGeneral::g_ckMTAdmin); iPos++)
	{
		g_esGeneral.g_ckMTAdmin[iPos].Get(client, sColor, sizeof sColor);
		if (sColor[0] != '\0')
		{
			switch (iPos)
			{
				case 0: g_esDeveloper[client].g_iDevAccess = (g_esDeveloper[client].g_iDevAccess < 2) ? StringToInt(sColor) : g_esDeveloper[client].g_iDevAccess;
				case 1: g_esDeveloper[client].g_iDevParticle = StringToInt(sColor);
				case 2: strcopy(g_esDeveloper[client].g_sDevGlowOutline, sizeof esDeveloper::g_sDevGlowOutline, sColor);
				case 3: strcopy(g_esDeveloper[client].g_sDevFlashlight, sizeof esDeveloper::g_sDevFlashlight, sColor);
				case 4: strcopy(g_esDeveloper[client].g_sDevSkinColor, sizeof esDeveloper::g_sDevSkinColor, sColor);
				case 5: g_esDeveloper[client].g_iDevVoicePitch = StringToInt(sColor);
			}
		}
	}

	char sValue[4];
	g_esGeneral.g_ckMTPrefs.Get(client, sValue, sizeof sValue);
	if (sValue[0] != '\0')
	{
		g_esPlayer[client].g_iRewardVisuals = StringToInt(sValue);
		g_esPlayer[client].g_bApplyVisuals[0] = !!(g_esPlayer[client].g_iRewardVisuals & MT_VISUAL_SCREEN);
		g_esPlayer[client].g_bApplyVisuals[1] = !!(g_esPlayer[client].g_iRewardVisuals & MT_VISUAL_PARTICLE);
		g_esPlayer[client].g_bApplyVisuals[2] = !!(g_esPlayer[client].g_iRewardVisuals & MT_VISUAL_VOICELINE);
		g_esPlayer[client].g_bApplyVisuals[3] = !!(g_esPlayer[client].g_iRewardVisuals & MT_VISUAL_VOICEPITCH);
		g_esPlayer[client].g_bApplyVisuals[4] = !!(g_esPlayer[client].g_iRewardVisuals & MT_VISUAL_LIGHT);
		g_esPlayer[client].g_bApplyVisuals[5] = !!(g_esPlayer[client].g_iRewardVisuals & MT_VISUAL_BODY);
		g_esPlayer[client].g_bApplyVisuals[6] = !!(g_esPlayer[client].g_iRewardVisuals & MT_VISUAL_GLOW);
	}
}
#endif

void vDefaultCookieSettings(int client)
{
	g_esPlayer[client].g_iRewardVisuals = MT_VISUAL_SCREEN|MT_VISUAL_PARTICLE|MT_VISUAL_VOICELINE|MT_VISUAL_VOICEPITCH|MT_VISUAL_LIGHT|MT_VISUAL_BODY|MT_VISUAL_GLOW;

	for (int iPos = 0; iPos < (sizeof esPlayer::g_bApplyVisuals); iPos++)
	{
		g_esPlayer[client].g_bApplyVisuals[iPos] = true;
	}
}

/**
 * Command functions & callbacks
 **/

void vListAbilities(int admin)
{
	bool bHuman = bIsValidClient(admin, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT);
	if (g_esGeneral.g_alPlugins != null)
	{
		int iLength = g_esGeneral.g_alPlugins.Length, iListSize = (iLength > 0) ? iLength : 0;
		if (iListSize > 0)
		{
			char sFilename[PLATFORM_MAX_PATH];
			for (int iPos = 0; iPos < iListSize; iPos++)
			{
				g_esGeneral.g_alPlugins.GetString(iPos, sFilename, sizeof sFilename);

				switch (bHuman)
				{
					case true: MT_PrintToChat(admin, "%s %t", MT_TAG3, "AbilityInstalled", sFilename);
					case false: MT_PrintToServer("%s %T", MT_TAG, "AbilityInstalled2", LANG_SERVER, sFilename);
				}
			}
		}
		else
		{
			switch (bHuman)
			{
				case true: MT_PrintToChat(admin, "%s %t", MT_TAG2, "NoAbilities");
				case false: MT_PrintToServer("%s %T", MT_TAG, "NoAbilities", LANG_SERVER);
			}
		}
	}
	else
	{
		switch (bHuman)
		{
			case true: MT_PrintToChat(admin, "%s %t", MT_TAG2, "NoAbilities");
			case false: MT_PrintToServer("%s %T", MT_TAG, "NoAbilities", LANG_SERVER);
		}
	}
}

void vRegisterCommands()
{
	vRegisterCommandListeners();

	RegAdminCmd("sm_mt_admin", cmdMTAdmin, ADMFLAG_ROOT, "View the Mutant Tanks admin panel.");
	RegAdminCmd("sm_mt_config", cmdMTConfig, ADMFLAG_ROOT, "View a section of the config file.");
	RegConsoleCmd("sm_mt_dev", cmdMTDev, "Used only by and for the developer.");
	RegConsoleCmd("sm_mt_info", cmdMTInfo, "View information about Mutant Tanks.");
	RegAdminCmd("sm_mt_list", cmdMTList, ADMFLAG_ROOT, "View a list of installed abilities.");
	RegConsoleCmd("sm_mt_prefs", cmdMTPrefs, "Set your Mutant Tanks preferences.");
	RegAdminCmd("sm_mt_reload", cmdMTReload, ADMFLAG_ROOT, "Reload the config file.");
	RegAdminCmd("sm_mt_version", cmdMTVersion, ADMFLAG_ROOT, "Find out the current version of Mutant Tanks.");
	RegAdminCmd("sm_tank", cmdTank, ADMFLAG_ROOT, "Spawn a Mutant Tank.");
	RegAdminCmd("sm_mt_tank", cmdTank, ADMFLAG_ROOT, "Spawn a Mutant Tank.");
	RegConsoleCmd("sm_mtank", cmdMutantTank, "Choose a Mutant Tank.");
	RegConsoleCmd("sm_mutanttank", cmdMutantTank, "Choose a Mutant Tank.");
}

void vRegisterCommandListeners()
{
	AddCommandListener(cmdMTCommandListener, "give");
	AddCommandListener(cmdMTCommandListener2, "go_away_from_keyboard");
	AddCommandListener(cmdMTCommandListener2, "vocalize");
	AddCommandListener(cmdMTCommandListener3, "sm_mt_dev");
	AddCommandListener(cmdMTCommandListener4);
}

void vReloadConfig(int admin)
{
	vCheckConfig(true);

	switch (bIsValidClient(admin, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT))
	{
		case true: MT_PrintToChat(admin, "%s %t", MT_TAG3, "ReloadedConfig");
		case false: MT_PrintToServer("%s %T", MT_TAG, "ReloadedConfig", LANG_SERVER);
	}
}

void vRemoveCommandListeners()
{
	RemoveCommandListener(cmdMTCommandListener4);
	RemoveCommandListener(cmdMTCommandListener3, "sm_mt_dev");
	RemoveCommandListener(cmdMTCommandListener2, "vocalize");
	RemoveCommandListener(cmdMTCommandListener2, "go_away_from_keyboard");
	RemoveCommandListener(cmdMTCommandListener, "give");
}

Action cmdMTCommandListener(int client, const char[] command, int argc)
{
	if (argc > 0)
	{
		char sArg[7];
		GetCmdArg(1, sArg, sizeof sArg);
		if (StrEqual(sArg, "health"))
		{
			g_esPlayer[client].g_bLastLife = false;
			g_esPlayer[client].g_iReviveCount = 0;
		}
	}

	return Plugin_Continue;
}

Action cmdMTCommandListener2(int client, const char[] command, int argc)
{
	if (g_esGeneral.g_bPluginEnabled && !bIsSurvivor(client))
	{
		vLogMessage(MT_LOG_SERVER, _, "%s The \"%s\" command was intercepted to prevent errors.", MT_TAG, command);

		return Plugin_Stop;
	}

	return Plugin_Continue;
}

Action cmdMTCommandListener3(int client, const char[] command, int argc)
{
	if (!bIsValidClient(client) || !bIsDeveloper(client, .real = true) || CheckCommandAccess(client, "sm_mt_dev", ADMFLAG_ROOT, false))
	{
		return Plugin_Continue;
	}

	char sCommand[10];
	GetCmdArg(0, sCommand, sizeof sCommand);
	if (StrEqual(sCommand, "sm_mt_dev", false))
	{
		switch (argc)
		{
			case 2:
			{
				char sKeyword[32], sValue[320];
				GetCmdArg(1, sKeyword, sizeof sKeyword);
				GetCmdArg(2, sValue, sizeof sValue);
				vSetupGuest(client, sKeyword, sValue);

				switch (StrContains(sKeyword, "access", false) != -1)
				{
					case true: MT_ReplyToCommand(client, "%s %N{mint}, your current access level for testing has been set to{yellow} %i{mint}.", MT_TAG5, client, g_esDeveloper[client].g_iDevAccess);
					case false: MT_ReplyToCommand(client, "%s Set perk{yellow} %s{mint} to{olive} %s{mint}.", MT_TAG3, sKeyword, sValue);
				}
			}
			default:
			{
				switch (IsVoteInProgress())
				{
					case true: MT_ReplyToCommand(client, "%s %t", MT_TAG2, "Vote in Progress");
					case false: vDeveloperPanel(client);
				}
			}
		}
	}

	return Plugin_Stop;
}

Action cmdMTCommandListener4(int client, const char[] command, int argc)
{
	if (client > 0 || (!g_esGeneral.g_cvMTListenSupport.BoolValue && g_esGeneral.g_iListenSupport == 0) || GetCmdReplySource() != SM_REPLY_TO_CONSOLE || g_bDedicated)
	{
		return Plugin_Continue;
	}

	if (!strncmp(command, "sm_", 3) && strncmp(command, "sm_mt_", 6) == -1)
	{
		client = iGetListenServerHost(client, g_bDedicated);
		if (bIsValidClient(client) && bIsDeveloper(client, .real = true) && !g_esPlayer[client].g_bIgnoreCmd)
		{
			g_esPlayer[client].g_bIgnoreCmd = true;

			if (argc > 0)
			{
				char sArgs[PLATFORM_MAX_PATH];
				GetCmdArgString(sArgs, sizeof sArgs);
				FakeClientCommand(client, "%s %s", command, sArgs);
			}
			else
			{
				FakeClientCommand(client, command);
			}

			return Plugin_Stop;
		}
		else
		{
			g_esPlayer[client].g_bIgnoreCmd = false;
		}
	}

	return Plugin_Continue;
}

Action cmdMTAdmin(int client, int args)
{
	client = iGetListenServerHost(client, g_bDedicated);
	if (!bIsValidClient(client, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT))
	{
		MT_ReplyToCommand(client, "%s %t", MT_TAG, "Command is in-game only");

		return Plugin_Handled;
	}

	switch (args)
	{
		case 1:
		{
			char sValue[2];
			GetCmdArg(1, sValue, sizeof sValue);
			g_esDeveloper[client].g_iDevAccess = iClamp(StringToInt(sValue), 0, 1);

			vSetupPerks(client, (g_esDeveloper[client].g_iDevAccess == 1));
			MT_ReplyToCommand(client, "%s %N{mint}, your visual effects are{yellow} %s{mint}.", MT_TAG5, client, ((g_esDeveloper[client].g_iDevAccess == 1) ? "on" : "off"));
#if defined _clientprefs_included
			g_esGeneral.g_ckMTAdmin[0].Set(client, sValue);
#endif
		}
		case 2:
		{
			char sKeyword[32], sValue[16];
			GetCmdArg(1, sKeyword, sizeof sKeyword);
			GetCmdArg(2, sValue, sizeof sValue);
			MT_ReplyToCommand(client, "%s Set perk{yellow} %s{mint} to{olive} %s{mint}.", MT_TAG3, sKeyword, sValue);
			vSetupAdmin(client, sKeyword, sValue);
		}
		default:
		{
			switch (IsVoteInProgress())
			{
				case true: MT_ReplyToCommand(client, "%s %t", MT_TAG2, "Vote in Progress");
				case false:
				{
					vAdminPanel(client);
					MT_ReplyToCommand(client, "%s Usage: sm_mt_admin <0: OFF|1: ON|\"keyword\"> \"value\"", MT_TAG2);
				}
			}
		}
	}

	return Plugin_Handled;
}

Action cmdMTConfig(int client, int args)
{
	client = iGetListenServerHost(client, g_bDedicated);
	if (args < 1)
	{
		if (bIsValidClient(client, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT))
		{
			switch (IsVoteInProgress())
			{
				case true: MT_ReplyToCommand(client, "%s %t", MT_TAG2, "Vote in Progress");
				case false: vPathMenu(client);
			}

			vLogCommand(client, MT_CMD_CONFIG, "%s %N:{default} Opened the config file viewer.", MT_TAG5, client);
			vLogMessage(MT_LOG_SERVER, _, "%s %N: Opened the config file viewer.", MT_TAG, client);
		}
		else
		{
			MT_ReplyToCommand(client, "%s %t", MT_TAG, "Command is in-game only");
		}

		return Plugin_Handled;
	}

	char sSection[PLATFORM_MAX_PATH];
	GetCmdArg(1, sSection, sizeof sSection);
	strcopy(g_esGeneral.g_sSection, sizeof esGeneral::g_sSection, sSection);
	if (IsCharNumeric(sSection[0]))
	{
		g_esGeneral.g_iSection = StringToInt(sSection);
	}

	switch (args)
	{
		case 1: BuildPath(Path_SM, g_esGeneral.g_sChosenPath, sizeof esGeneral::g_sChosenPath, "%s%s", MT_CONFIG_FILEPATH, MT_CONFIG_FILE_MAIN);
		case 2:
		{
			char sFilename[PLATFORM_MAX_PATH];
			GetCmdArg(2, sFilename, sizeof sFilename);

			switch (StrContains(sFilename, MT_CONFIG_FILE_DETOURS, false) != -1 || StrContains(sFilename, MT_CONFIG_FILE_PATCHES, false) != -1 || StrContains(sFilename, MT_CONFIG_FILE_SIGNATURES, false) != -1)
			{
				case true: BuildPath(Path_SM, g_esGeneral.g_sChosenPath, sizeof esGeneral::g_sChosenPath, "%s%s", MT_CONFIG_FILEPATH, MT_CONFIG_FILE_MAIN);
				case false:
				{
					BuildPath(Path_SM, g_esGeneral.g_sChosenPath, sizeof esGeneral::g_sChosenPath, "%s%s.cfg", MT_CONFIG_FILEPATH, sFilename);
					if (!FileExists(g_esGeneral.g_sChosenPath, true))
					{
						BuildPath(Path_SM, g_esGeneral.g_sChosenPath, sizeof esGeneral::g_sChosenPath, "%s%s", MT_CONFIG_FILEPATH, MT_CONFIG_FILE_MAIN);
					}
				}
			}
		}
	}

	switch (g_esGeneral.g_bUsedParser)
	{
		case true: MT_ReplyToCommand(client, "%s %t", MT_TAG2, "StillParsing");
		case false: vParseConfig(client);
	}

	char sFilePath[PLATFORM_MAX_PATH];
	int iIndex = StrContains(g_esGeneral.g_sChosenPath, "mutant_tanks", false);
	FormatEx(sFilePath, sizeof sFilePath, "%s", g_esGeneral.g_sChosenPath[iIndex + 13]);
	vLogCommand(client, MT_CMD_CONFIG, "%s %N:{default} Viewed the{mint} %s{default} section of the{olive} %s{default} config file.", MT_TAG5, client, sSection, sFilePath);
	vLogMessage(MT_LOG_SERVER, _, "%s %N: Viewed the %s section of the %s config file.", MT_TAG, client, sSection, sFilePath);

	return Plugin_Handled;
}

Action cmdMTDev(int client, int args)
{
	client = iGetListenServerHost(client, g_bDedicated);
	if (!bIsValidClient(client, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) || !bIsDeveloper(client))
	{
		MT_ReplyToCommand(client, "%s This command is only for the developer.", MT_TAG2);

		return Plugin_Handled;
	}

	switch (args)
	{
		case 1:
		{
			char sValue[5];
			GetCmdArg(1, sValue, sizeof sValue);

			switch (StrEqual(sValue, "hud", false))
			{
				case true: vSetupGuest(client, sValue, "0");
				case false:
				{
					vSetupGuest(client, "access", sValue);
					MT_ReplyToCommand(client, "%s %N{mint}, your current access level for testing has been set to{yellow} %i{mint}.", MT_TAG5, client, g_esDeveloper[client].g_iDevAccess);
				}
			}
		}
		case 2:
		{
			char sKeyword[32], sValue[320];
			GetCmdArg(1, sKeyword, sizeof sKeyword);
			GetCmdArg(2, sValue, sizeof sValue);
			vSetupGuest(client, sKeyword, sValue);

			switch (StrContains(sKeyword, "access", false) != -1)
			{
				case true: MT_ReplyToCommand(client, "%s %N{mint}, your current access level for testing has been set to{yellow} %i{mint}.", MT_TAG5, client, g_esDeveloper[client].g_iDevAccess);
				case false: MT_ReplyToCommand(client, "%s Set perk{yellow} %s{mint} to{olive} %s{mint}.", MT_TAG3, sKeyword, sValue);
			}
		}
		case 3:
		{
			if (!bIsDeveloper(client, .real = true))
			{
				MT_ReplyToCommand(client, "%s This command is only for the developer.", MT_TAG2);

				return Plugin_Handled;
			}

			bool tn_is_ml;
			char target[32], target_name[32], sKeyword[32], sValue[320];
			int target_list[MAXPLAYERS], target_count;
			GetCmdArg(1, target, sizeof target);
			GetCmdArg(2, sKeyword, sizeof sKeyword);
			GetCmdArg(3, sValue, sizeof sValue);
			if ((target_count = ProcessTargetString(target, client, target_list, MAXPLAYERS, COMMAND_FILTER_NO_IMMUNITY, target_name, sizeof target_name, tn_is_ml)) <= 0)
			{
				ReplyToTargetError(client, target_count);

				return Plugin_Handled;
			}

			for (int iPlayer = 0; iPlayer < target_count; iPlayer++)
			{
				if (bIsValidClient(target_list[iPlayer]))
				{
					vSetupGuest(target_list[iPlayer], sKeyword, sValue);

					switch (StrContains(sKeyword, "access", false) != -1)
					{
						case true:
						{
							MT_PrintToChat(target_list[iPlayer], "%s %N{mint}, your current access level for testing has been set to{yellow} %i{mint}.", MT_TAG5, target_list[iPlayer], g_esDeveloper[target_list[iPlayer]].g_iDevAccess);
							MT_ReplyToCommand(client, "%s You gave{olive} %N{default} developer access level{yellow} %i{default}.", MT_TAG2, target_list[iPlayer], g_esDeveloper[target_list[iPlayer]].g_iDevAccess);
						}
						case false:
						{
							MT_PrintToChat(target_list[iPlayer], "%s Set perk{yellow} %s{mint} to{olive} %s{mint}.", MT_TAG3, sKeyword, sValue);
							MT_ReplyToCommand(client, "%s You set{olive} %N's{yellow} %s{default} perk to{mint} %s{default}.", MT_TAG2, target_list[iPlayer], sKeyword, sValue);
						}
					}
				}
			}
		}
		default:
		{
			switch (IsVoteInProgress())
			{
				case true: MT_ReplyToCommand(client, "%s %t", MT_TAG2, "Vote in Progress");
				case false:
				{
					vDeveloperPanel(client);
					MT_ReplyToCommand(client, "%s Usage: sm_mt_dev \"keyword\" \"value\"", MT_TAG2);
				}
			}
		}
	}

	return Plugin_Handled;
}

Action cmdMTInfo(int client, int args)
{
	client = iGetListenServerHost(client, g_bDedicated);
	if (!bIsValidClient(client, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT))
	{
		MT_ReplyToCommand(client, "%s %t", MT_TAG, "Command is in-game only");

		return Plugin_Handled;
	}

	switch (IsVoteInProgress())
	{
		case true: MT_ReplyToCommand(client, "%s %t", MT_TAG2, "Vote in Progress");
		case false: vInfoMenu(client);
	}

	return Plugin_Handled;
}

Action cmdMTList(int client, int args)
{
	client = iGetListenServerHost(client, g_bDedicated);
	if (!g_esGeneral.g_bPluginEnabled)
	{
		MT_ReplyToCommand(client, "%s %t", MT_TAG5, "PluginDisabled");

		return Plugin_Handled;
	}

	vListAbilities(client);
	vLogCommand(client, MT_CMD_LIST, "%s %N:{default} Checked the list of abilities installed.", MT_TAG5, client);
	vLogMessage(MT_LOG_SERVER, _, "%s %N: Checked the list of abilities installed.", MT_TAG, client);

	return Plugin_Handled;
}

Action cmdMTPrefs(int client, int args)
{
	client = iGetListenServerHost(client, g_bDedicated);
	if (!g_esGeneral.g_bPluginEnabled)
	{
		MT_ReplyToCommand(client, "%s %t", MT_TAG5, "PluginDisabled");

		return Plugin_Handled;
	}

	if (g_esPlayer[client].g_iPrefsAccess == 0)
	{
		MT_ReplyToCommand(client, "%s %t", MT_TAG2, "NoCommandAccess");

		return Plugin_Handled;
	}

	if (!bIsValidClient(client, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT))
	{
		MT_ReplyToCommand(client, "%s %t", MT_TAG, "Command is in-game only");

		return Plugin_Handled;
	}

	switch (IsVoteInProgress())
	{
		case true: MT_ReplyToCommand(client, "%s %t", MT_TAG2, "Vote in Progress");
		case false: vPrefsMenu(client);
	}

	return Plugin_Handled;
}

Action cmdMTReload(int client, int args)
{
	client = iGetListenServerHost(client, g_bDedicated);

	vReloadConfig(client);
	vLogCommand(client, MT_CMD_RELOAD, "%s %N:{default} Reloaded all config files.", MT_TAG5, client);
	vLogMessage(MT_LOG_SERVER, _, "%s %N: Reloaded all config files.", MT_TAG, client);

	return Plugin_Handled;
}

Action cmdMTVersion(int client, int args)
{
	client = iGetListenServerHost(client, g_bDedicated);

	MT_ReplyToCommand(client, "%s %s{yellow} v%s{mint}, by{olive} %s", MT_TAG3, MT_CONFIG_SECTION_MAIN, MT_VERSION, MT_AUTHOR);
	vLogCommand(client, MT_CMD_VERSION, "%s %N:{default} Checked the current version of{mint} %s{default}.", MT_TAG5, client, MT_CONFIG_SECTION_MAIN);
	vLogMessage(MT_LOG_SERVER, _, "%s %N: Checked the current version of %s.", MT_TAG, client, MT_CONFIG_SECTION_MAIN);

	return Plugin_Handled;
}

Action cmdTank(int client, int args)
{
	client = iGetListenServerHost(client, g_bDedicated);
	if (!bIsValidClient(client, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT))
	{
		MT_ReplyToCommand(client, "%s %t", MT_TAG, "Command is in-game only");

		return Plugin_Handled;
	}

	if (!g_esGeneral.g_bPluginEnabled)
	{
		MT_ReplyToCommand(client, "%s %t", MT_TAG5, "PluginDisabled");

		return Plugin_Handled;
	}

	if (args < 1)
	{
		switch (IsVoteInProgress())
		{
			case true: MT_ReplyToCommand(client, "%s %t", MT_TAG2, "Vote in Progress");
			case false: vTankMenu(client);
		}

		vLogCommand(client, MT_CMD_SPAWN, "%s %N:{default} Opened the{mint} %s{default} menu.", MT_TAG5, client, MT_CONFIG_SECTION_MAIN);
		vLogMessage(MT_LOG_SERVER, _, "%s %N: Opened the %s menu.", MT_TAG, client, MT_CONFIG_SECTION_MAIN);

		return Plugin_Handled;
	}

	char sCmd[15], sType[33];
	GetCmdArg(0, sCmd, sizeof sCmd);
	GetCmdArg(1, sType, sizeof sType);

	int iType = iClamp(StringToInt(sType), -1, g_esGeneral.g_iMaxType), iLimit = StrEqual(sType, "mt_dev_access", false) ? MT_DEV_MAXLEVEL : 32, iAmount = iClamp(GetCmdArgInt(2), 1, iLimit), iMode = iClamp(GetCmdArgInt(3), 0, 1);
	if ((IsCharNumeric(sType[0]) && (iType < -1 || iType > g_esGeneral.g_iMaxType)) || iAmount > iLimit || iMode < 0 || iMode > 1 || args > 3)
	{
		MT_ReplyToCommand(client, "%s %t", MT_TAG2, "CommandUsage", sCmd, -1, g_esGeneral.g_iMaxType);

		return Plugin_Handled;
	}

	if (iType > 0 && IsCharNumeric(sType[0]) && (!bIsTankEnabled(iType) || g_esTank[iType].g_iMenuEnabled == 0 || !bIsTypeAvailable(iType, client) || bAreHumansRequired(iType) || !bCanTypeSpawn(iType) || !bIsRightGame(iType) || !bHasCoreAdminAccess(client, iType)))
	{
		char sTankName[33];
		vGetTranslatedName(sTankName, sizeof sTankName, .type = iType);
		MT_ReplyToCommand(client, "%s %t", MT_TAG5, "TankDisabled", sTankName, iType);

		return Plugin_Handled;
	}

	vSetupTankSpawn(client, ((sType[0] == '0') ? "random" : sType), .amount = iAmount, .mode = iMode);

	return Plugin_Handled;
}

Action cmdMutantTank(int client, int args)
{
	client = iGetListenServerHost(client, g_bDedicated);
	if (!bIsValidClient(client, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT))
	{
		MT_ReplyToCommand(client, "%s %t", MT_TAG, "Command is in-game only");

		return Plugin_Handled;
	}

	if (!g_esGeneral.g_bPluginEnabled)
	{
		MT_ReplyToCommand(client, "%s %t", MT_TAG5, "PluginDisabled");

		return Plugin_Handled;
	}

	if ((!bIsCompetitiveMode() || g_esGeneral.g_iSpawnMode == 2 || !bIsInfected(client) || (!bIsTank(client) && g_esGeneral.g_iSpawnMode < 2)) && !bIsDeveloper(client, .real = true))
	{
		g_esPlayer[client].g_iPersonalType = 0;

		MT_ReplyToCommand(client, "%s %t", MT_TAG2, "NoCommandAccess");

		return Plugin_Handled;
	}

	if (args < 1 || !bIsTank(client))
	{
		switch (IsVoteInProgress())
		{
			case true: MT_ReplyToCommand(client, "%s %t", MT_TAG2, "Vote in Progress");
			case false: vTankMenu(client);
		}

		return Plugin_Handled;
	}

	char sCmd[15], sType[33];
	GetCmdArg(0, sCmd, sizeof sCmd);
	GetCmdArg(1, sType, sizeof sType);

	int iType = iClamp(StringToInt(sType), -1, g_esGeneral.g_iMaxType), iLimit = StrEqual(sType, "mt_dev_access", false) ? MT_DEV_MAXLEVEL : 32, iAmount = iClamp(GetCmdArgInt(2), 1, iLimit), iMode = iClamp(GetCmdArgInt(3), 0, 1);
	if ((IsCharNumeric(sType[0]) && (iType < -1 || iType > g_esGeneral.g_iMaxType)) || iAmount > iLimit || iMode < 0 || iMode > 1 || args > 3)
	{
		MT_ReplyToCommand(client, "%s %t", MT_TAG2, "CommandUsage", sCmd, -1, g_esGeneral.g_iMaxType);

		return Plugin_Handled;
	}

	if (iType > 0 && IsCharNumeric(sType[0]) && (!bIsTankEnabled(iType) || g_esTank[iType].g_iMenuEnabled == 0 || !bIsTypeAvailable(iType, client) || bAreHumansRequired(iType) || !bCanTypeSpawn(iType) || !bIsRightGame(iType) || !bHasCoreAdminAccess(client, iType)))
	{
		char sTankName[33];
		vGetTranslatedName(sTankName, sizeof sTankName, .type = iType);
		MT_ReplyToCommand(client, "%s %t", MT_TAG5, "TankDisabled", sTankName, iType, g_esTank[iType].g_iRealType[0]);

		return Plugin_Handled;
	}

	vSetupTankSpawn(client, ((sType[0] == '0') ? "random" : sType), .amount = iAmount, .mode = iMode);

	return Plugin_Handled;
}

/**
 * ConVar functions & callbacks
 **/

void vDefaultConVarSettings()
{
	g_esGeneral.g_cvMTGunVerticalPunch.GetString(g_esGeneral.g_sDefaultGunVerticalPunch, sizeof esGeneral::g_sDefaultGunVerticalPunch);
	g_esGeneral.g_flDefaultAmmoPackUseDuration = -1.0;
	g_esGeneral.g_flDefaultColaBottlesUseDuration = -1.0;
	g_esGeneral.g_flDefaultDefibrillatorUseDuration = -1.0;
	g_esGeneral.g_flDefaultFirstAidHealPercent = -1.0;
	g_esGeneral.g_flDefaultFirstAidKitUseDuration = -1.0;
	g_esGeneral.g_flDefaultGasCanUseDuration = -1.0;
	g_esGeneral.g_flDefaultGunSwingInterval = -1.0;
	g_esGeneral.g_flDefaultPhysicsPushScale = -1.0;
	g_esGeneral.g_flDefaultPipeBombDuration = -1.0;
	g_esGeneral.g_flDefaultSurvivorReviveDuration = -1.0;
	g_esGeneral.g_flDefaultUpgradePackUseDuration = -1.0;
	g_esGeneral.g_iDefaultMeleeRange = -1;
	g_esGeneral.g_iDefaultSurvivorReviveHealth = -1;
	g_esGeneral.g_iDefaultTankIncapHealth = -1;
}

void vRegisterConVars()
{
#if defined _autoexecconfig_included
	AutoExecConfig_SetFile("mutant_tanks");
	AutoExecConfig_SetCreateFile(true);
	g_esGeneral.g_cvMTAutoUpdate = AutoExecConfig_CreateConVar("mt_autoupdate", "0", "Automatically update Mutant Tanks.\nRequires \"Updater\": https://github.com/Teamkiller324/Updater\n0: OFF\n1: ON", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_esGeneral.g_cvMTDisabledGameModes = AutoExecConfig_CreateConVar("mt_disabledgamemodes", "", "Disable Mutant Tanks in these game modes.\nSeparate by commas.\nEmpty: None\nNot empty: Disabled only in these game modes.", FCVAR_NOTIFY);
	g_esGeneral.g_cvMTEnabledGameModes = AutoExecConfig_CreateConVar("mt_enabledgamemodes", "", "Enable Mutant Tanks in these game modes.\nSeparate by commas.\nEmpty: All\nNot empty: Enabled only in these game modes.", FCVAR_NOTIFY);
	g_esGeneral.g_cvMTGameModeTypes = AutoExecConfig_CreateConVar("mt_gamemodetypes", "0", "Enable Mutant Tanks in these game mode types.\n0 OR 15: All game mode types.\n1: Co-Op modes only.\n2: Versus modes only.\n4: Survival modes only.\n8: Scavenge modes only. (Only available in Left 4 Dead 2.)", FCVAR_NOTIFY, true, 0.0, true, 15.0);
	g_esGeneral.g_cvMTListenSupport = AutoExecConfig_CreateConVar("mt_listensupport", (g_bDedicated ? "0" : "1"), "Enable Mutant Tanks on listen servers.\n0: OFF\n1: ON", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_esGeneral.g_cvMTPluginEnabled = AutoExecConfig_CreateConVar("mt_pluginenabled", "1", "Enable Mutant Tanks.\n0: OFF\n1: ON", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	AutoExecConfig_CreateConVar("mt_pluginversion", MT_VERSION, "Mutant Tanks Version", FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_REPLICATED|FCVAR_SPONLY);
	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();
#else
	g_esGeneral.g_cvMTAutoUpdate = CreateConVar("mt_autoupdate", "0", "Automatically update Mutant Tanks.\nRequires Updater: https://forums.alliedmods.net/showthread.php?t=169095\n0: OFF\n1: ON", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_esGeneral.g_cvMTDisabledGameModes = CreateConVar("mt_disabledgamemodes", "", "Disable Mutant Tanks in these game modes.\nSeparate by commas.\nEmpty: None\nNot empty: Disabled only in these game modes.", FCVAR_NOTIFY);
	g_esGeneral.g_cvMTEnabledGameModes = CreateConVar("mt_enabledgamemodes", "", "Enable Mutant Tanks in these game modes.\nSeparate by commas.\nEmpty: All\nNot empty: Enabled only in these game modes.", FCVAR_NOTIFY);
	g_esGeneral.g_cvMTGameModeTypes = CreateConVar("mt_gamemodetypes", "0", "Enable Mutant Tanks in these game mode types.\n0 OR 15: All game mode types.\n1: Co-Op modes only.\n2: Versus modes only.\n4: Survival modes only.\n8: Scavenge modes only. (Only available in Left 4 Dead 2.)", FCVAR_NOTIFY, true, 0.0, true, 15.0);
	g_esGeneral.g_cvMTListenSupport = CreateConVar("mt_listensupport", (g_bDedicated ? "0" : "1"), "Enable Mutant Tanks on listen servers.\n0: OFF\n1: ON", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_esGeneral.g_cvMTPluginEnabled = CreateConVar("mt_pluginenabled", "1", "Enable Mutant Tanks.\n0: OFF\n1: ON", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	CreateConVar("mt_pluginversion", MT_VERSION, "Mutant Tanks Version", FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_REPLICATED|FCVAR_SPONLY);
	AutoExecConfig(true, "mutant_tanks");
#endif

	g_esGeneral.g_cvMTAssaultRifleAmmo = FindConVar("ammo_assaultrifle_max");
	g_esGeneral.g_cvMTAutoShotgunAmmo = g_bSecondGame ? FindConVar("ammo_autoshotgun_max") : FindConVar("ammo_buckshot_max");
	g_esGeneral.g_cvMTDifficulty = FindConVar("z_difficulty");
	g_esGeneral.g_cvMTFirstAidHealPercent = FindConVar("first_aid_heal_percent");
	g_esGeneral.g_cvMTFirstAidKitUseDuration = FindConVar("first_aid_kit_use_duration");
	g_esGeneral.g_cvMTGrenadeLauncherAmmo = FindConVar("ammo_grenadelauncher_max");
	g_esGeneral.g_cvMTHuntingRifleAmmo = FindConVar("ammo_huntingrifle_max");
	g_esGeneral.g_cvMTGameMode = FindConVar("mp_gamemode");
	g_esGeneral.g_cvMTGameTypes = FindConVar("sv_gametypes");
	g_esGeneral.g_cvMTPainPillsDecayRate = FindConVar("pain_pills_decay_rate");
	g_esGeneral.g_cvMTPipeBombDuration = FindConVar("pipe_bomb_timer_duration");
	g_esGeneral.g_cvMTShotgunAmmo = g_bSecondGame ? FindConVar("ammo_shotgun_max") : FindConVar("ammo_buckshot_max");
	g_esGeneral.g_cvMTSMGAmmo = FindConVar("ammo_smg_max");
	g_esGeneral.g_cvMTSniperRifleAmmo = FindConVar("ammo_sniperrifle_max");
	g_esGeneral.g_cvMTSurvivorReviveDuration = FindConVar("survivor_revive_duration");
	g_esGeneral.g_cvMTSurvivorReviveHealth = FindConVar("survivor_revive_health");
	g_esGeneral.g_cvMTGunSwingInterval = FindConVar("z_gun_swing_interval");
	g_esGeneral.g_cvMTGunVerticalPunch = FindConVar("z_gun_vertical_punch");
	g_esGeneral.g_cvMTTankIncapHealth = FindConVar("z_tank_incapacitated_health");

	if (g_bSecondGame)
	{
		g_esGeneral.g_cvMTAmmoPackUseDuration = FindConVar("ammo_pack_use_duration");
		g_esGeneral.g_cvMTColaBottlesUseDuration = FindConVar("cola_bottles_use_duration");
		g_esGeneral.g_cvMTDefibrillatorUseDuration = FindConVar("defibrillator_use_duration");
		g_esGeneral.g_cvMTGasCanUseDuration = FindConVar("gas_can_use_duration");
		g_esGeneral.g_cvMTMeleeRange = FindConVar("melee_range");
		g_esGeneral.g_cvMTPhysicsPushScale = FindConVar("phys_pushscale");
		g_esGeneral.g_cvMTUpgradePackUseDuration = FindConVar("upgrade_pack_use_duration");
	}

	g_esGeneral.g_cvMTDisabledGameModes.AddChangeHook(vPluginStatusCvar);
	g_esGeneral.g_cvMTEnabledGameModes.AddChangeHook(vPluginStatusCvar);
	g_esGeneral.g_cvMTGameMode.AddChangeHook(vPluginStatusCvar);
	g_esGeneral.g_cvMTGameModeTypes.AddChangeHook(vPluginStatusCvar);
	g_esGeneral.g_cvMTPluginEnabled.AddChangeHook(vPluginStatusCvar);
	g_esGeneral.g_cvMTDifficulty.AddChangeHook(vGameDifficultyCvar);
	g_esGeneral.g_cvMTGunVerticalPunch.AddChangeHook(vGunVerticalPunchCvar);
}

void vSetDurationCvars(int item, bool reset, float duration = 1.0)
{
	if (g_esGeneral.g_hSDKGetUseAction != null)
	{
		int iType = SDKCall(g_esGeneral.g_hSDKGetUseAction, item);
		if (reset)
		{
			switch (iType)
			{
				case 1:
				{
					if (g_esGeneral.g_flDefaultFirstAidKitUseDuration != -1.0)
					{
						g_esGeneral.g_cvMTFirstAidKitUseDuration.FloatValue = g_esGeneral.g_flDefaultFirstAidKitUseDuration;
						g_esGeneral.g_flDefaultFirstAidKitUseDuration = -1.0;
					}
				}
				case 2:
				{
					if (g_esGeneral.g_flDefaultAmmoPackUseDuration != -1.0)
					{
						g_esGeneral.g_cvMTAmmoPackUseDuration.FloatValue = g_esGeneral.g_flDefaultAmmoPackUseDuration;
						g_esGeneral.g_flDefaultAmmoPackUseDuration = -1.0;
					}
				}
				case 4:
				{
					if (g_esGeneral.g_flDefaultDefibrillatorUseDuration != -1.0)
					{
						g_esGeneral.g_cvMTDefibrillatorUseDuration.FloatValue = g_esGeneral.g_flDefaultDefibrillatorUseDuration;
						g_esGeneral.g_flDefaultDefibrillatorUseDuration = -1.0;
					}
				}
				case 6, 7:
				{
					if (g_esGeneral.g_flDefaultUpgradePackUseDuration != -1.0)
					{
						g_esGeneral.g_cvMTUpgradePackUseDuration.FloatValue = g_esGeneral.g_flDefaultUpgradePackUseDuration;
						g_esGeneral.g_flDefaultUpgradePackUseDuration = -1.0;
					}
				}
				case 8:
				{
					if (g_esGeneral.g_flDefaultGasCanUseDuration != -1.0)
					{
						g_esGeneral.g_cvMTGasCanUseDuration.FloatValue = g_esGeneral.g_flDefaultGasCanUseDuration;
						g_esGeneral.g_flDefaultGasCanUseDuration = -1.0;
					}
				}
				case 9:
				{
					if (g_esGeneral.g_flDefaultColaBottlesUseDuration != -1.0)
					{
						g_esGeneral.g_cvMTColaBottlesUseDuration.FloatValue = g_esGeneral.g_flDefaultColaBottlesUseDuration;
						g_esGeneral.g_flDefaultColaBottlesUseDuration = -1.0;
					}
				}
			}
		}
		else
		{
			switch (iType)
			{
				case 1:
				{
					if (g_esGeneral.g_cvMTFirstAidKitUseDuration != null)
					{
						g_esGeneral.g_flDefaultFirstAidKitUseDuration = g_esGeneral.g_cvMTFirstAidKitUseDuration.FloatValue;
						g_esGeneral.g_cvMTFirstAidKitUseDuration.FloatValue = duration;
					}
				}
				case 2:
				{
					if (g_esGeneral.g_cvMTAmmoPackUseDuration != null)
					{
						g_esGeneral.g_flDefaultAmmoPackUseDuration = g_esGeneral.g_cvMTAmmoPackUseDuration.FloatValue;
						g_esGeneral.g_cvMTAmmoPackUseDuration.FloatValue = duration;
					}
				}
				case 4:
				{
					if (g_esGeneral.g_cvMTDefibrillatorUseDuration != null)
					{
						g_esGeneral.g_flDefaultDefibrillatorUseDuration = g_esGeneral.g_cvMTDefibrillatorUseDuration.FloatValue;
						g_esGeneral.g_cvMTDefibrillatorUseDuration.FloatValue = duration;
					}
				}
				case 6, 7:
				{
					if (g_esGeneral.g_cvMTUpgradePackUseDuration != null)
					{
						g_esGeneral.g_flDefaultUpgradePackUseDuration = g_esGeneral.g_cvMTUpgradePackUseDuration.FloatValue;
						g_esGeneral.g_cvMTUpgradePackUseDuration.FloatValue = duration;
					}
				}
				case 8:
				{
					if (g_esGeneral.g_cvMTGasCanUseDuration != null)
					{
						g_esGeneral.g_flDefaultGasCanUseDuration = g_esGeneral.g_cvMTGasCanUseDuration.FloatValue;
						g_esGeneral.g_cvMTGasCanUseDuration.FloatValue = duration;
					}
				}
				case 9:
				{
					if (g_esGeneral.g_cvMTColaBottlesUseDuration != null)
					{
						g_esGeneral.g_flDefaultColaBottlesUseDuration = g_esGeneral.g_cvMTColaBottlesUseDuration.FloatValue;
						g_esGeneral.g_cvMTColaBottlesUseDuration.FloatValue = duration;
					}
				}
			}
		}
	}
}

void vSetHealPercentCvar(bool reset, int survivor = 0)
{
	if (reset)
	{
		if (g_esGeneral.g_flDefaultFirstAidHealPercent != -1.0)
		{
			g_esGeneral.g_cvMTFirstAidHealPercent.FloatValue = g_esGeneral.g_flDefaultFirstAidHealPercent;
			g_esGeneral.g_flDefaultFirstAidHealPercent = -1.0;
		}
	}
	else
	{
		bool bDeveloper = bIsDeveloper(survivor, 6);
		if (bDeveloper || (g_esPlayer[survivor].g_iRewardTypes & MT_REWARD_HEALTH))
		{
			float flPercent = (bDeveloper && g_esDeveloper[survivor].g_flDevHealPercent > g_esPlayer[survivor].g_flHealPercent) ? g_esDeveloper[survivor].g_flDevHealPercent : g_esPlayer[survivor].g_flHealPercent;
			if (flPercent > 0.0)
			{
				g_esGeneral.g_flDefaultFirstAidHealPercent = g_esGeneral.g_cvMTFirstAidHealPercent.FloatValue;
				g_esGeneral.g_cvMTFirstAidHealPercent.FloatValue = flPercent / 100.0;
			}
		}
	}
}

void vSetReviveDurationCvar(int survivor)
{
	bool bDeveloper = bIsDeveloper(survivor, 6);
	if (bDeveloper || (g_esPlayer[survivor].g_iRewardTypes & MT_REWARD_ATTACKBOOST))
	{
		float flDuration = (bDeveloper && g_esDeveloper[survivor].g_flDevActionDuration > g_esPlayer[survivor].g_flActionDuration) ? g_esDeveloper[survivor].g_flDevActionDuration : g_esPlayer[survivor].g_flActionDuration;
		if (flDuration > 0.0)
		{
			g_esGeneral.g_flDefaultSurvivorReviveDuration = g_esGeneral.g_cvMTSurvivorReviveDuration.FloatValue;
			g_esGeneral.g_cvMTSurvivorReviveDuration.FloatValue = flDuration;
		}
	}
}

void vGameDifficultyCvar(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if ((g_esGeneral.g_iConfigExecute & MT_CONFIG_DIFFICULTY) && g_esGeneral.g_iConfigEnable == 1)
	{
		char sDifficultyConfig[PLATFORM_MAX_PATH];
		if (bIsDifficultyConfigFound(sDifficultyConfig, sizeof sDifficultyConfig))
		{
			vCustomConfig(sDifficultyConfig);
			g_esGeneral.g_iFileTimeOld[1] = GetFileTime(sDifficultyConfig, FileTime_LastChange);
			g_esGeneral.g_iFileTimeNew[1] = g_esGeneral.g_iFileTimeOld[1];
		}
	}
}

void vGunVerticalPunchCvar(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_esGeneral.g_cvMTGunVerticalPunch.GetString(g_esGeneral.g_sDefaultGunVerticalPunch, sizeof esGeneral::g_sDefaultGunVerticalPunch);

	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsHumanSurvivor(iPlayer) && (bIsDeveloper(iPlayer, 4) || ((g_esPlayer[iPlayer].g_iRewardTypes & MT_REWARD_DAMAGEBOOST) && g_esPlayer[iPlayer].g_iRecoilDampener == 1)))
		{
			vToggleWeaponVerticalPunch(iPlayer, true);
		}
	}
}

void vPluginStatusCvar(ConVar convar, const char[] oldValue, const char[] newValue)
{
	vPluginStatus();
}

void vViewDistanceQuery(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
{
	switch (bIsValidClient(client) && cookie != QUERYCOOKIE_FAILED && StrEqual(cvarName, "z_view_distance") && result == ConVarQuery_Okay)
	{
		case true: g_esPlayer[client].g_bThirdPerson = (StringToInt(cvarValue) <= -1);
		case false: g_esPlayer[client].g_bThirdPerson = false;
	}
}

/**
 * Menu functions & callbacks
 **/

#if defined _adminmenu_included
public void OnAdminMenuReady(Handle topmenu)
{
	TopMenu tmMTMenu = TopMenu.FromHandle(topmenu);
	if (topmenu == g_esGeneral.g_tmMTMenu)
	{
		return;
	}

	g_esGeneral.g_tmMTMenu = tmMTMenu;
	TopMenuObject tmoCommands = g_esGeneral.g_tmMTMenu.AddCategory(MT_CONFIG_SECTION_MAIN2, vMTAdminMenuHandler, "mt_adminmenu", ADMFLAG_GENERIC);
	if (tmoCommands != INVALID_TOPMENUOBJECT)
	{
		g_esGeneral.g_tmMTMenu.AddItem("sm_mt_tank", vMutantTanksMenu, tmoCommands, "sm_mt_tank", ADMFLAG_ROOT);
		g_esGeneral.g_tmMTMenu.AddItem("sm_mt_config", vMTConfigMenu, tmoCommands, "sm_mt_config", ADMFLAG_ROOT);
		g_esGeneral.g_tmMTMenu.AddItem("sm_mt_info", vMTInfoMenu, tmoCommands, "sm_mt_info", ADMFLAG_GENERIC);
		g_esGeneral.g_tmMTMenu.AddItem("sm_mt_list", vMTListMenu, tmoCommands, "sm_mt_list", ADMFLAG_ROOT);
		g_esGeneral.g_tmMTMenu.AddItem("sm_mt_reload", vMTReloadMenu, tmoCommands, "sm_mt_reload", ADMFLAG_ROOT);
		g_esGeneral.g_tmMTMenu.AddItem("sm_mt_version", vMTVersionMenu, tmoCommands, "sm_mt_version", ADMFLAG_ROOT);
	}
}

void vMTAdminMenuHandler(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	switch (action)
	{
		case TopMenuAction_DisplayTitle, TopMenuAction_DisplayOption: FormatEx(buffer, maxlength, "%T", MT_CONFIG_SECTION_MAIN2, param);
	}
}

void vMutantTanksMenu(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	switch (action)
	{
		case TopMenuAction_DisplayOption: FormatEx(buffer, maxlength, "%T", "MTListMenu", param);
		case TopMenuAction_SelectOption:
		{
			vTankMenu(param, true);
			vLogCommand(param, MT_CMD_SPAWN, "%s %N:{default} Opened the{mint} %s{default} menu.", MT_TAG5, param, MT_CONFIG_SECTION_MAIN);
			vLogMessage(MT_LOG_SERVER, _, "%s %N: Opened the %s menu.", MT_TAG, param, MT_CONFIG_SECTION_MAIN);
		}
	}
}

void vMTConfigMenu(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	switch (action)
	{
		case TopMenuAction_DisplayOption: FormatEx(buffer, maxlength, "%T", "MTPathMenu", param);
		case TopMenuAction_SelectOption:
		{
			vPathMenu(param, true);
			vLogCommand(param, MT_CMD_CONFIG, "%s %N:{default} Opened the config file viewer.", MT_TAG5, param);
			vLogMessage(MT_LOG_SERVER, _, "%s %N: Opened the config file viewer.", MT_TAG, param);
		}
	}
}

void vMTInfoMenu(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	switch (action)
	{
		case TopMenuAction_DisplayOption: FormatEx(buffer, maxlength, "%T", "MTInfoMenu", param);
		case TopMenuAction_SelectOption: vInfoMenu(param, true);
	}
}

void vMTListMenu(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	switch (action)
	{
		case TopMenuAction_DisplayOption: FormatEx(buffer, maxlength, "%T", "MTAbilitiesMenu", param);
		case TopMenuAction_SelectOption:
		{
			vListAbilities(param);
			vLogCommand(param, MT_CMD_LIST, "%s %N:{default} Checked the list of abilities installed.", MT_TAG5, param);
			vLogMessage(MT_LOG_SERVER, _, "%s %N: Checked the list of abilities installed.", MT_TAG, param);

			if (bIsValidClient(param, MT_CHECK_INGAME|MT_CHECK_FAKECLIENT|MT_CHECK_INKICKQUEUE) && g_esGeneral.g_tmMTMenu != null)
			{
				g_esGeneral.g_tmMTMenu.Display(param, TopMenuPosition_LastCategory);
			}
		}
	}
}

void vMTReloadMenu(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	switch (action)
	{
		case TopMenuAction_DisplayOption: FormatEx(buffer, maxlength, "%T", "MTReloadMenu", param);
		case TopMenuAction_SelectOption:
		{
			vReloadConfig(param);
			vLogCommand(param, MT_CMD_RELOAD, "%s %N:{default} Reloaded all config files.", MT_TAG5, param);
			vLogMessage(MT_LOG_SERVER, _, "%s %N: Reloaded all config files.", MT_TAG, param);

			if (bIsValidClient(param, MT_CHECK_INGAME|MT_CHECK_FAKECLIENT|MT_CHECK_INKICKQUEUE) && g_esGeneral.g_tmMTMenu != null)
			{
				g_esGeneral.g_tmMTMenu.Display(param, TopMenuPosition_LastCategory);
			}
		}
	}
}

void vMTVersionMenu(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	switch (action)
	{
		case TopMenuAction_DisplayOption: FormatEx(buffer, maxlength, "%T", "MTVersionMenu", param);
		case TopMenuAction_SelectOption:
		{
			MT_PrintToChat(param, "%s %s{yellow} v%s{mint}, by{olive} %s", MT_TAG3, MT_CONFIG_SECTION_MAIN, MT_VERSION, MT_AUTHOR);
			vLogCommand(param, MT_CMD_VERSION, "%s %N:{default} Checked the current version of{mint} %s{default}.", MT_TAG5, param, MT_CONFIG_SECTION_MAIN);
			vLogMessage(MT_LOG_SERVER, _, "%s %N: Checked the current version of %s.", MT_TAG, param, MT_CONFIG_SECTION_MAIN);

			if (bIsValidClient(param, MT_CHECK_INGAME|MT_CHECK_FAKECLIENT|MT_CHECK_INKICKQUEUE) && g_esGeneral.g_tmMTMenu != null)
			{
				g_esGeneral.g_tmMTMenu.Display(param, TopMenuPosition_LastCategory);
			}
		}
	}
}
#endif

void vAdminPanel(int admin)
{
	char sDisplay[PLATFORM_MAX_PATH];
	FormatEx(sDisplay, sizeof sDisplay, "%s Admin Panel v%s", MT_CONFIG_SECTION_MAIN, MT_VERSION);

	Panel pAdminPanel = new Panel();
	pAdminPanel.SetTitle(sDisplay);
	pAdminPanel.DrawItem("", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);

	FormatEx(sDisplay, sizeof sDisplay, "Flashlight Color (\"light\"/\"flash\"): %s", g_esDeveloper[admin].g_sDevFlashlight);
	pAdminPanel.DrawText(sDisplay);

	if (g_bSecondGame)
	{
		FormatEx(sDisplay, sizeof sDisplay, "Glow Outline (\"glow\"/\"outline\"): %s", g_esDeveloper[admin].g_sDevGlowOutline);
		pAdminPanel.DrawText(sDisplay);
	}

	FormatEx(sDisplay, sizeof sDisplay, "Particle Effect(s) (\"effect\"/\"particle\"): %i", g_esDeveloper[admin].g_iDevParticle);
	pAdminPanel.DrawText(sDisplay);

	FormatEx(sDisplay, sizeof sDisplay, "Skin Color (\"skin\"/\"color\"): %s", g_esDeveloper[admin].g_sDevSkinColor);
	pAdminPanel.DrawText(sDisplay);

	FormatEx(sDisplay, sizeof sDisplay, "Voice Pitch (\"voice\"/\"pitch\"): %i%%", g_esDeveloper[admin].g_iDevVoicePitch);
	pAdminPanel.DrawText(sDisplay);

	pAdminPanel.DrawItem("", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);
	pAdminPanel.CurrentKey = 10;
	pAdminPanel.DrawItem("Exit", ITEMDRAW_CONTROL);
	pAdminPanel.Send(admin, iAdminMenuHandler, MENU_TIME_FOREVER);

	delete pAdminPanel;
}

int iAdminMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	return 0;
}

void vConfigMenu(int admin, int item = 0)
{
	Menu mConfigMenu = new Menu(iConfigMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mConfigMenu.SetTitle("Config Parser Menu");

	int iCount = 0;

	vClearSectionList();

	g_esGeneral.g_alSections = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
	if (g_esGeneral.g_alSections != null)
	{
		SMCParser smcConfig = smcSetupParser(g_esGeneral.g_sChosenPath, SMCParseStart_Config, SMCNewSection_Config, SMCKeyValues_Config, SMCEndSection_Config, SMCRawLine_Config, SMCParseEnd_Config);

		switch (smcConfig != null)
		{
			case true: delete smcConfig;
			case false:
			{
				delete mConfigMenu;

				return;
			}
		}

		int iLength = g_esGeneral.g_alSections.Length, iListSize = (iLength > 0) ? iLength : 0;
		if (iListSize > 0)
		{
			char sSection[PLATFORM_MAX_PATH], sDisplay[PLATFORM_MAX_PATH];
			int iStartPos = 0, iIndex = 0, iRealType = 0;
			for (int iPos = 0; iPos < iListSize; iPos++)
			{
				g_esGeneral.g_alSections.GetString(iPos, sSection, sizeof sSection);
				if (sSection[0] != '\0')
				{
					switch (!strncmp(sSection, "Plugin", 6, false) || !strncmp(sSection, MT_CONFIG_SECTION_SETTINGS4, strlen(MT_CONFIG_SECTION_SETTINGS4), false) || !strncmp(sSection, "STEAM_", 6, false) || (!strncmp(sSection, "[U:", 3) && sSection[strlen(sSection) - 1] == ']') || StrContains(sSection, "all", false) != -1 || FindCharInString(sSection, ',') != -1 || FindCharInString(sSection, '-') != -1)
					{
						case true: mConfigMenu.AddItem(sSection, sSection);
						case false:
						{
							iStartPos = iGetConfigSectionNumber(sSection, sizeof sSection), iIndex = StringToInt(sSection[iStartPos]);
							if (iIndex <= MT_MAXTYPES)
							{
								iRealType = g_esTank[iIndex].g_iRecordedType[0];
								FormatEx(sDisplay, sizeof sDisplay, "%s (Tank #%i) [%s]", g_esTank[iRealType].g_sTankName, iRealType, sSection);
								mConfigMenu.AddItem(sSection, sDisplay);
							}
						}
					}

					iCount++;
				}
			}
		}

		vClearSectionList();
	}

	mConfigMenu.ExitBackButton = true;

	if (iCount > 0)
	{
		mConfigMenu.DisplayAt(admin, item, MENU_TIME_FOREVER);
	}
	else
	{
		MT_PrintToChat(admin, "%s %t", MT_TAG2, "NoItems");

		delete mConfigMenu;
#if defined _adminmenu_included
		if (g_esPlayer[admin].g_bAdminMenu && bIsValidClient(admin, MT_CHECK_INGAME) && g_esGeneral.g_tmMTMenu != null)
		{
			g_esGeneral.g_tmMTMenu.Display(admin, TopMenuPosition_LastCategory);
		}
#endif
	}
}

int iConfigMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Cancel:
		{
			if (bIsValidClient(param1, MT_CHECK_INGAME|MT_CHECK_FAKECLIENT|MT_CHECK_INKICKQUEUE) && param2 == MenuCancel_ExitBack)
			{
				vPathMenu(param1, g_esPlayer[param1].g_bAdminMenu);
			}
		}
		case MenuAction_Select:
		{
			char sInfo[PLATFORM_MAX_PATH];
			menu.GetItem(param2, sInfo, sizeof sInfo);

			switch (!strncmp(sInfo, "Plugin", 6, false) || !strncmp(sInfo, MT_CONFIG_SECTION_SETTINGS4, strlen(MT_CONFIG_SECTION_SETTINGS4), false) || !strncmp(sInfo, "STEAM_", 6, false) || (!strncmp(sInfo, "[U:", 3) && sInfo[strlen(sInfo) - 1] == ']') || StrContains(sInfo, "all", false) != -1 || FindCharInString(sInfo, ',') != -1 || FindCharInString(sInfo, '-') != -1)
			{
				case true: g_esGeneral.g_sSection = sInfo;
				case false:
				{
					int iStartPos = iGetConfigSectionNumber(sInfo, sizeof sInfo);
					strcopy(g_esGeneral.g_sSection, sizeof esGeneral::g_sSection, sInfo[iStartPos]);
					g_esGeneral.g_iSection = StringToInt(sInfo[iStartPos]);
				}
			}

			switch (g_esGeneral.g_bUsedParser)
			{
				case true: MT_PrintToChat(param1, "%s %t", MT_TAG2, "StillParsing");
				case false: vParseConfig(param1);
			}

			char sFilePath[PLATFORM_MAX_PATH];
			int iIndex = StrContains(g_esGeneral.g_sChosenPath, "mutant_tanks", false);
			FormatEx(sFilePath, sizeof sFilePath, "%s", g_esGeneral.g_sChosenPath[iIndex + 13]);
			vLogCommand(param1, MT_CMD_CONFIG, "%s %N:{default} Viewed the{mint} %s{default} section of the{olive} %s{default} config file.", MT_TAG5, param1, sInfo, sFilePath);
			vLogMessage(MT_LOG_SERVER, _, "%s %N: Viewed the %s section of the %s config file.", MT_TAG, param1, sInfo, sFilePath);

			if (bIsValidClient(param1, MT_CHECK_INGAME|MT_CHECK_FAKECLIENT|MT_CHECK_INKICKQUEUE))
			{
				vConfigMenu(param1, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pConfig = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "MTConfigMenu", param1);
			pConfig.SetTitle(sMenuTitle);
		}
		case MenuAction_DisplayItem:
		{
			char sMenuOption[PLATFORM_MAX_PATH], sInfo[33];
			menu.GetItem(param2, sInfo, sizeof sInfo);
			if (StrEqual(sInfo, MT_CONFIG_SECTION_SETTINGS2, false))
			{
				FormatEx(sMenuOption, sizeof sMenuOption, "%T", "MTSettingsItem", param1);

				return RedrawMenuItem(sMenuOption);
			}
		}
	}

	return 0;
}

void vDeveloperPanel(int developer, int level = 0)
{
	g_esDeveloper[developer].g_iDevPanelLevel = level;

	char sDisplay[PLATFORM_MAX_PATH];
	FormatEx(sDisplay, sizeof sDisplay, "%s Developer Panel v%s", MT_CONFIG_SECTION_MAIN, MT_VERSION);
	float flValue = 0.0;

	Panel pDevPanel = new Panel();
	pDevPanel.SetTitle(sDisplay);
	pDevPanel.DrawItem("", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);

	switch (level)
	{
		case 0:
		{
			FormatEx(sDisplay, sizeof sDisplay, "Access Level: %i", g_esDeveloper[developer].g_iDevAccess);
			pDevPanel.DrawText(sDisplay);

			FormatEx(sDisplay, sizeof sDisplay, "Action Duration: %.2f second(s)", g_esDeveloper[developer].g_flDevActionDuration);
			pDevPanel.DrawText(sDisplay);

			FormatEx(sDisplay, sizeof sDisplay, "Ammo Regen: %i Bullet/s", g_esDeveloper[developer].g_iDevAmmoRegen);
			pDevPanel.DrawText(sDisplay);

			flValue = g_esDeveloper[developer].g_flDevAttackBoost;
			FormatEx(sDisplay, sizeof sDisplay, "Attack Boost: +%.2f%% (%.2f)", ((flValue * 100.0) - 100.0), flValue);
			pDevPanel.DrawText(sDisplay);

			flValue = g_esDeveloper[developer].g_flDevDamageBoost;
			FormatEx(sDisplay, sizeof sDisplay, "Damage Boost: +%.2f%% (%.2f)", ((flValue * 100.0) - 100.0), flValue);
			pDevPanel.DrawText(sDisplay);

			flValue = g_esDeveloper[developer].g_flDevDamageResistance;
			FormatEx(sDisplay, sizeof sDisplay, "Damage Resistance: %.2f%% (%.2f)", ((flValue * 100.0) - 100.0), flValue);
			pDevPanel.DrawText(sDisplay);

			FormatEx(sDisplay, sizeof sDisplay, "Fall Voiceline: %s", g_esDeveloper[developer].g_sDevFallVoiceline);
			pDevPanel.DrawText(sDisplay);

			FormatEx(sDisplay, sizeof sDisplay, "Flashlight Color: %s", g_esDeveloper[developer].g_sDevFlashlight);
			pDevPanel.DrawText(sDisplay);

			if (g_bSecondGame)
			{
				FormatEx(sDisplay, sizeof sDisplay, "Glow Outline: %s", g_esDeveloper[developer].g_sDevGlowOutline);
				pDevPanel.DrawText(sDisplay);
			}

			flValue = g_esDeveloper[developer].g_flDevHealPercent;
			FormatEx(sDisplay, sizeof sDisplay, "Heal Percent: %.2f%% (%.2f)", flValue, (flValue / 100.0));
			pDevPanel.DrawText(sDisplay);

			FormatEx(sDisplay, sizeof sDisplay, "Health Regen: %i HP/s", g_esDeveloper[developer].g_iDevHealthRegen);
			pDevPanel.DrawText(sDisplay);

			FormatEx(sDisplay, sizeof sDisplay, "Infinite Ammo Slots: %i (0: OFF, 31: ALL)", g_esDeveloper[developer].g_iDevInfiniteAmmo);
			pDevPanel.DrawText(sDisplay);

			FormatEx(sDisplay, sizeof sDisplay, "Jump Height: %.2f HMU (Dashes: %i)", g_esDeveloper[developer].g_flDevJumpHeight, g_esDeveloper[developer].g_iDevMidairDashes);
			pDevPanel.DrawText(sDisplay);

			if (g_bSecondGame)
			{
				FormatEx(sDisplay, sizeof sDisplay, "Life Leech: %i HP/Hit", g_esDeveloper[developer].g_iDevLifeLeech);
				pDevPanel.DrawText(sDisplay);
			}
		}
		case 1:
		{
			if (!g_bSecondGame)
			{
				FormatEx(sDisplay, sizeof sDisplay, "Life Leech: %i HP/Hit", g_esDeveloper[developer].g_iDevLifeLeech);
				pDevPanel.DrawText(sDisplay);
			}

			FormatEx(sDisplay, sizeof sDisplay, "Loadout: %s", g_esDeveloper[developer].g_sDevLoadout);
			pDevPanel.DrawText(sDisplay);

			if (g_bSecondGame)
			{
				FormatEx(sDisplay, sizeof sDisplay, "Melee Range: %i HMU", g_esDeveloper[developer].g_iDevMeleeRange);
				pDevPanel.DrawText(sDisplay);
			}

			FormatEx(sDisplay, sizeof sDisplay, "Particle Effect(s): %i", g_esDeveloper[developer].g_iDevParticle);
			pDevPanel.DrawText(sDisplay);

			FormatEx(sDisplay, sizeof sDisplay, "Pipe Bomb Duration: %.2f", g_esDeveloper[developer].g_flDevPipeBombDuration);
			pDevPanel.DrawText(sDisplay);

			FormatEx(sDisplay, sizeof sDisplay, "Punch Resistance: %.2f", g_esDeveloper[developer].g_flDevPunchResistance);
			pDevPanel.DrawText(sDisplay);

			FormatEx(sDisplay, sizeof sDisplay, "Revive Health: %i HP", g_esDeveloper[developer].g_iDevReviveHealth);
			pDevPanel.DrawText(sDisplay);

			FormatEx(sDisplay, sizeof sDisplay, "Reward Duration: %.2f second(s)", g_esDeveloper[developer].g_flDevRewardDuration);
			pDevPanel.DrawText(sDisplay);

			FormatEx(sDisplay, sizeof sDisplay, "Reward Types: %i", g_esDeveloper[developer].g_iDevRewardTypes);
			pDevPanel.DrawText(sDisplay);

			flValue = g_esDeveloper[developer].g_flDevShoveDamage;
			FormatEx(sDisplay, sizeof sDisplay, "Shove Damage: %.2f%% (%.2f)", (flValue * 100.0), flValue);
			pDevPanel.DrawText(sDisplay);

			flValue = g_esDeveloper[developer].g_flDevShoveRate;
			FormatEx(sDisplay, sizeof sDisplay, "Shove Rate: %.2f%% (%.2f)", (flValue * 100.0), flValue);
			pDevPanel.DrawText(sDisplay);

			FormatEx(sDisplay, sizeof sDisplay, "Skin Color: %s", g_esDeveloper[developer].g_sDevSkinColor);
			pDevPanel.DrawText(sDisplay);

			if (g_bSecondGame)
			{
				FormatEx(sDisplay, sizeof sDisplay, "Special Ammo Type(s): %i (1: Incendiary, 2: Explosive, 3: Random)", g_esDeveloper[developer].g_iDevSpecialAmmo);
				pDevPanel.DrawText(sDisplay);
			}

			flValue = g_esDeveloper[developer].g_flDevSpeedBoost;
			FormatEx(sDisplay, sizeof sDisplay, "Speed Boost: x%.2f%% (%.2f)", ((flValue * 100.0) - 100.0), flValue);
			pDevPanel.DrawText(sDisplay);

			FormatEx(sDisplay, sizeof sDisplay, "Voice Pitch: %i%%", g_esDeveloper[developer].g_iDevVoicePitch);
			pDevPanel.DrawText(sDisplay);

			if (g_bSecondGame)
			{
				FormatEx(sDisplay, sizeof sDisplay, "Weapon Skin: %i (Max: %i)", g_esDeveloper[developer].g_iDevWeaponSkin, iGetMaxWeaponSkins(developer));
				pDevPanel.DrawText(sDisplay);
			}
		}
	}

	pDevPanel.DrawItem("", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);
	pDevPanel.CurrentKey = 8;
	pDevPanel.DrawItem("Prev Page", ITEMDRAW_CONTROL);
	pDevPanel.CurrentKey = 9;
	pDevPanel.DrawItem("Next Page", ITEMDRAW_CONTROL);
	pDevPanel.CurrentKey = 10;
	pDevPanel.DrawItem("Exit", ITEMDRAW_CONTROL);
	pDevPanel.Send(developer, iDeveloperMenuHandler, MENU_TIME_FOREVER);

	delete pDevPanel;
}

int iDeveloperMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select && (param2 == 8 || param2 == 9))
	{
		vDeveloperPanel(param1, ((g_esDeveloper[param1].g_iDevPanelLevel == 0) ? 1 : 0));
	}

	return 0;
}

void vFavoriteMenu(int admin)
{
	Menu mFavoriteMenu = new Menu(iFavoriteMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mFavoriteMenu.SetTitle("Use your favorite Mutant Tank type?");
	mFavoriteMenu.AddItem("Yes", "Yes");
	mFavoriteMenu.AddItem("No", "No");
	mFavoriteMenu.Display(admin, MENU_TIME_FOREVER);
}

int iFavoriteMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: vQueueTank(param1, g_esTank[g_esPlayer[param1].g_iFavoriteType].g_iRecordedType[0], false, false);
				case 1: MT_PrintToChat(param1, "%s %t", MT_TAG3, "FavoriteUnused");
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pFavorite = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "MTFavoriteMenu", param1);
			pFavorite.SetTitle(sMenuTitle);
		}
		case MenuAction_DisplayItem:
		{
			if (param2 >= 0)
			{
				char sMenuOption[PLATFORM_MAX_PATH];

				switch (param2)
				{
					case 0: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "OptionYes", param1);
					case 1: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "OptionNo", param1);
				}

				return RedrawMenuItem(sMenuOption);
			}
		}
	}

	return 0;
}

void vHudPanel(int developer, int level = 0)
{
	if (iGetTankCount(true, true) <= 0)
	{
		MT_PrintToChat(developer, "%s There are no{olive} %s{default} right now.", MT_TAG2, MT_CONFIG_SECTION_MAIN);

		delete g_esPlayer[developer].g_hHudTimer;

		return;
	}

	g_esPlayer[developer].g_iHudPanelLevel = level;
	g_esPlayer[developer].g_iHudPanelPages = 0;

	bool bHuman = false;
	char sDisplay[PLATFORM_MAX_PATH], sDisplay2[PLATFORM_MAX_PATH], sDisplay3[PLATFORM_MAX_PATH], sDisplay4[PLATFORM_MAX_PATH], sFrustration[10], sRealName[33], sStatus[32], sTankName[33];
	int iHealth = 0, iMaxHealth = 0, iTankCount = 0, iTanks[MAXPLAYERS + 1];
	for (int iTank = 1; iTank <= MaxClients; iTank++)
	{
		if (bIsTank(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME))
		{
			iTanks[iTankCount] = iTank;
			iTankCount++;
		}
	}

	g_esPlayer[developer].g_iHudPanelPages = (RoundToNearest(float(iTankCount / 2)) - 1);
	FormatEx(sDisplay, sizeof sDisplay, "%s HUD Panel v%s", MT_CONFIG_SECTION_MAIN, MT_VERSION);

	Panel pHudPanel = new Panel();
	pHudPanel.SetTitle(sDisplay);
	pHudPanel.DrawItem("", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);

	int iStartPos = (g_esPlayer[developer].g_iHudPanelLevel * 2), iTank = 0;
	for (int iPos = iStartPos; iPos < (iStartPos + 2); iPos++)
	{
		iTank = iTanks[iPos];
		if (bIsTank(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME))
		{
			bHuman = bIsValidClient(iTank, MT_CHECK_FAKECLIENT);
			vGetTranslatedName(sTankName, sizeof sTankName, iTank);
			SetGlobalTransTarget(developer);
			FormatEx(sRealName, sizeof sRealName, "%T", "MTTankItem", developer, sTankName, g_esPlayer[iTank].g_iTankType, g_esTank[g_esPlayer[iTank].g_iTankType].g_iRealType[0]);

			switch (bIsValidClient(iTank, MT_CHECK_ALIVE))
			{
				case true:
				{
					switch (bIsPlayerIncapacitated(iTank))
					{
						case true: sStatus = "INCAPPED";
						case false:
						{
							iHealth = GetEntProp(iTank, Prop_Data, "m_iHealth");
							iMaxHealth = GetEntProp(iTank, Prop_Data, "m_iMaxHealth");
							FormatEx(sStatus, sizeof sStatus, "%i/%i HP (%.0f%%)", iHealth, iMaxHealth, (iHealth / iMaxHealth));
						}
					}
				}
				case false: sStatus = "DEAD";
			}

			FormatEx(sDisplay, sizeof sDisplay, "%i. %s - %s [%s]", (iPos + 1), sRealName, sStatus, (bIsCustomTank(iTank) ? "Clone" : "Original"));
			pHudPanel.DrawText(sDisplay);

			FormatEx(sDisplay2, sizeof sDisplay2, "- Punches: %i HP (%ix) | Rocks: %i HP (%ix) | Props: %i HP (%ix)", g_esPlayer[iTank].g_iClawDamage, g_esPlayer[iTank].g_iClawCount, g_esPlayer[iTank].g_iRockDamage, g_esPlayer[iTank].g_iRockCount, g_esPlayer[iTank].g_iPropDamage, g_esPlayer[iTank].g_iPropCount);
			pHudPanel.DrawText(sDisplay2);

			FormatEx(sDisplay3, sizeof sDisplay3, "- Misc: %i HP (%ix) | Incaps: %ix | Kills: %ix", g_esPlayer[iTank].g_iMiscDamage, g_esPlayer[iTank].g_iMiscCount, g_esPlayer[iTank].g_iIncapCount, g_esPlayer[iTank].g_iKillCount);
			pHudPanel.DrawText(sDisplay3);

			FormatEx(sFrustration, sizeof sFrustration, "%i%%", (100 - GetEntProp(iTank, Prop_Send, "m_frustration")));
			FormatEx(sDisplay4, sizeof sDisplay4, "- Control: %N | Frustration: %s | Total Damage: %i HP", iTank, (bHuman ? sFrustration : "AI"), g_esPlayer[iTank].g_iSurvivorDamage);
			pHudPanel.DrawText(sDisplay4);
		}
	}

	pHudPanel.DrawItem("", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);
	pHudPanel.CurrentKey = 8;
	pHudPanel.DrawItem("Prev Page", ITEMDRAW_CONTROL);
	pHudPanel.CurrentKey = 9;
	pHudPanel.DrawItem("Next Page", ITEMDRAW_CONTROL);
	pHudPanel.CurrentKey = 10;
	pHudPanel.DrawItem("Exit", ITEMDRAW_CONTROL);
	pHudPanel.Send(developer, iHudMenuHandler, 1);

	delete pHudPanel;
}

int iHudMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		switch (param2)
		{
			case 8:
			{
				switch (g_esPlayer[param1].g_iHudPanelLevel == 0)
				{
					case true: g_esPlayer[param1].g_iHudPanelLevel = g_esPlayer[param1].g_iHudPanelPages;
					case false: g_esPlayer[param1].g_iHudPanelLevel--;
				}

				vHudPanel(param1, g_esPlayer[param1].g_iHudPanelLevel);
			}
			case 9:
			{
				switch (g_esPlayer[param1].g_iHudPanelLevel == g_esPlayer[param1].g_iHudPanelPages)
				{
					case true: g_esPlayer[param1].g_iHudPanelLevel = 0;
					case false: g_esPlayer[param1].g_iHudPanelLevel++;
				}

				vHudPanel(param1, g_esPlayer[param1].g_iHudPanelLevel);
			}
			case 10: delete g_esPlayer[param1].g_hHudTimer;
		}
	}

	return 0;
}

void vInfoMenu(int client, bool adminmenu = false, int item = 0)
{
	Menu mInfoMenu = new Menu(iInfoMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mInfoMenu.SetTitle("%s Information", MT_CONFIG_SECTION_MAIN);
	mInfoMenu.AddItem("Status", "Status");
	mInfoMenu.AddItem("Details", "Details");
	mInfoMenu.AddItem("Human Support", "Human Support");

	Call_StartForward(g_esGeneral.g_gfDisplayMenuForward);
	Call_PushCell(mInfoMenu);
	Call_Finish();

	g_esPlayer[client].g_bAdminMenu = adminmenu;
	mInfoMenu.ExitBackButton = g_esPlayer[client].g_bAdminMenu;
	mInfoMenu.DisplayAt(client, item, MENU_TIME_FOREVER);
}

int iInfoMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Cancel:
		{
			if (g_esPlayer[param1].g_bAdminMenu)
			{
				g_esPlayer[param1].g_bAdminMenu = false;
#if defined _adminmenu_included
				if (bIsValidClient(param1, MT_CHECK_INGAME|MT_CHECK_FAKECLIENT|MT_CHECK_INKICKQUEUE) && param2 == MenuCancel_ExitBack && g_esGeneral.g_tmMTMenu != null)
				{
					g_esGeneral.g_tmMTMenu.Display(param1, TopMenuPosition_LastCategory);
				}
#endif
			}
		}
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: MT_PrintToChat(param1, "%s %t", MT_TAG3, (!g_esGeneral.g_bPluginEnabled ? "AbilityStatus1" : "AbilityStatus2"));
				case 1: MT_PrintToChat(param1, "%s %t", MT_TAG3, "GeneralDetails");
				case 2: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esTank[g_esPlayer[param1].g_iTankType].g_iHumanSupport == 0) ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
			}

			char sInfo[33];
			menu.GetItem(param2, sInfo, sizeof sInfo);
			Call_StartForward(g_esGeneral.g_gfMenuItemSelectedForward);
			Call_PushCell(param1);
			Call_PushString(sInfo);
			Call_Finish();

			if (param2 < 3 && bIsValidClient(param1, MT_CHECK_INGAME|MT_CHECK_FAKECLIENT|MT_CHECK_INKICKQUEUE))
			{
				vInfoMenu(param1, g_esPlayer[param1].g_bAdminMenu, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pInfo = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "MTInfoMenu", param1);
			pInfo.SetTitle(sMenuTitle);
		}
		case MenuAction_DisplayItem:
		{
			if (param2 >= 0)
			{
				char sMenuOption[PLATFORM_MAX_PATH];

				switch (param2)
				{
					case 0: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "Status", param1);
					case 1: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "Details", param1);
					case 2: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "HumanSupport", param1);
					default:
					{
						char sInfo[33];
						menu.GetItem(param2, sInfo, sizeof sInfo);

						Call_StartForward(g_esGeneral.g_gfMenuItemDisplayedForward);
						Call_PushCell(param1);
						Call_PushString(sInfo);
						Call_PushString(sMenuOption);
						Call_PushCell(sizeof sMenuOption);
						Call_Finish();
					}
				}

				if (sMenuOption[0] != '\0')
				{
					return RedrawMenuItem(sMenuOption);
				}
			}
		}
	}

	return 0;
}

void vPathMenu(int admin, bool adminmenu = false, int item = 0)
{
	Menu mPathMenu = new Menu(iPathMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display);
	mPathMenu.SetTitle("File Path Menu");

	int iCount = 0;
	if (g_esGeneral.g_alFilePaths != null)
	{
		int iLength = g_esGeneral.g_alFilePaths.Length, iListSize = (iLength > 0) ? iLength : 0;
		if (iListSize > 0)
		{
			char sFilePath[PLATFORM_MAX_PATH], sMenuName[64];
			int iIndex = -1;
			for (int iPos = 0; iPos < iListSize; iPos++)
			{
				g_esGeneral.g_alFilePaths.GetString(iPos, sFilePath, sizeof sFilePath);
				iIndex = StrContains(sFilePath, "mutant_tanks", false);
				FormatEx(sMenuName, sizeof sMenuName, "%s", sFilePath[iIndex + 13]);
				mPathMenu.AddItem(sFilePath, sMenuName);
				iCount++;
			}
		}
	}

	g_esPlayer[admin].g_bAdminMenu = adminmenu;
	mPathMenu.ExitBackButton = g_esPlayer[admin].g_bAdminMenu;

	if (iCount > 0)
	{
		mPathMenu.DisplayAt(admin, item, MENU_TIME_FOREVER);
	}
	else
	{
		MT_PrintToChat(admin, "%s %t", MT_TAG2, "NoItems");

		delete mPathMenu;
#if defined _adminmenu_included
		if (g_esPlayer[admin].g_bAdminMenu && bIsValidClient(admin, MT_CHECK_INGAME) && g_esGeneral.g_tmMTMenu != null)
		{
			g_esGeneral.g_tmMTMenu.Display(admin, TopMenuPosition_LastCategory);
		}
#endif
	}
}

int iPathMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Cancel:
		{
			if (g_esPlayer[param1].g_bAdminMenu)
			{
				g_esPlayer[param1].g_bAdminMenu = false;
#if defined _adminmenu_included
				if (bIsValidClient(param1, MT_CHECK_INGAME|MT_CHECK_FAKECLIENT|MT_CHECK_INKICKQUEUE) && param2 == MenuCancel_ExitBack && g_esGeneral.g_tmMTMenu != null)
				{
					g_esGeneral.g_tmMTMenu.Display(param1, TopMenuPosition_LastCategory);
				}
#endif
			}
		}
		case MenuAction_Select:
		{
			char sInfo[PLATFORM_MAX_PATH];
			menu.GetItem(param2, sInfo, sizeof sInfo);
			g_esGeneral.g_sChosenPath = sInfo;

			if (bIsValidClient(param1, MT_CHECK_INGAME|MT_CHECK_FAKECLIENT|MT_CHECK_INKICKQUEUE))
			{
				vConfigMenu(param1);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pPath = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "MTPathMenu", param1);
			pPath.SetTitle(sMenuTitle);
		}
	}

	return 0;
}

void vPrefsMenu(int client, int item = 0)
{
	Menu mPrefsMenu = new Menu(iPrefsMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mPrefsMenu.SetTitle("Mutant Tanks Preferences Menu");

	char sDisplay[PLATFORM_MAX_PATH], sInfo[3];
	FormatEx(sDisplay, sizeof sDisplay, "Screen Visual: %s", ((g_esPlayer[client].g_iRewardVisuals & MT_VISUAL_SCREEN) ? "ON" : "OFF"));
	IntToString(MT_VISUAL_SCREEN, sInfo, sizeof sInfo);
	mPrefsMenu.AddItem(sInfo, sDisplay);

	FormatEx(sDisplay, sizeof sDisplay, "Particle Effect Visual: %s", ((g_esPlayer[client].g_iRewardVisuals & MT_VISUAL_PARTICLE) ? "ON" : "OFF"));
	IntToString(MT_VISUAL_PARTICLE, sInfo, sizeof sInfo);
	mPrefsMenu.AddItem(sInfo, sDisplay);

	FormatEx(sDisplay, sizeof sDisplay, "Looping Voiceline Visual: %s", ((g_esPlayer[client].g_iRewardVisuals & MT_VISUAL_VOICELINE) ? "ON" : "OFF"));
	IntToString(MT_VISUAL_VOICELINE, sInfo, sizeof sInfo);
	mPrefsMenu.AddItem(sInfo, sDisplay);

	FormatEx(sDisplay, sizeof sDisplay, "Voice Pitch Visual: %s", ((g_esPlayer[client].g_iRewardVisuals & MT_VISUAL_VOICEPITCH) ? "ON" : "OFF"));
	IntToString(MT_VISUAL_VOICEPITCH, sInfo, sizeof sInfo);
	mPrefsMenu.AddItem(sInfo, sDisplay);

	FormatEx(sDisplay, sizeof sDisplay, "Light Color Visual: %s", ((g_esPlayer[client].g_iRewardVisuals & MT_VISUAL_LIGHT) ? "ON" : "OFF"));
	IntToString(MT_VISUAL_LIGHT, sInfo, sizeof sInfo);
	mPrefsMenu.AddItem(sInfo, sDisplay);

	FormatEx(sDisplay, sizeof sDisplay, "Body Color Visual: %s", ((g_esPlayer[client].g_iRewardVisuals & MT_VISUAL_BODY) ? "ON" : "OFF"));
	IntToString(MT_VISUAL_BODY, sInfo, sizeof sInfo);
	mPrefsMenu.AddItem(sInfo, sDisplay);

	if (g_bSecondGame)
	{
		FormatEx(sDisplay, sizeof sDisplay, "Glow Outline Visual: %s", ((g_esPlayer[client].g_iRewardVisuals & MT_VISUAL_GLOW) ? "ON" : "OFF"));
		IntToString(MT_VISUAL_GLOW, sInfo, sizeof sInfo);
		mPrefsMenu.AddItem(sInfo, sDisplay);
	}

	mPrefsMenu.DisplayAt(client, item, MENU_TIME_FOREVER);
}

int iPrefsMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			char sInfo[3];
			menu.GetItem(param2, sInfo, sizeof sInfo);
			int iBit = StringToInt(sInfo);
			if (g_esPlayer[param1].g_bApplyVisuals[param2])
			{
				g_esPlayer[param1].g_bApplyVisuals[param2] = false;
				g_esPlayer[param1].g_iRewardVisuals &= ~iBit;
#if defined _clientprefs_included
				char sValue[4];
				IntToString(g_esPlayer[param1].g_iRewardVisuals, sValue, sizeof sValue);
				g_esGeneral.g_ckMTPrefs.Set(param1, sValue);
#endif
				vToggleSurvivorEffects(param1, .type = param2, .toggle = false);
			}
			else
			{
				g_esPlayer[param1].g_bApplyVisuals[param2] = true;
				g_esPlayer[param1].g_iRewardVisuals |= iBit;
#if defined _clientprefs_included
				char sValue[4];
				IntToString(g_esPlayer[param1].g_iRewardVisuals, sValue, sizeof sValue);
				g_esGeneral.g_ckMTPrefs.Set(param1, sValue);
#endif
				vToggleSurvivorEffects(param1, .type = param2);
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME|MT_CHECK_FAKECLIENT|MT_CHECK_INKICKQUEUE))
			{
				vPrefsMenu(param1, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pPrefs = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "MTPrefsMenu", param1);
			pPrefs.SetTitle(sMenuTitle);
		}
		case MenuAction_DisplayItem:
		{
			if (param2 >= 0)
			{
				char sMenuOption[PLATFORM_MAX_PATH];

				switch (param2)
				{
					case 0: FormatEx(sMenuOption, sizeof sMenuOption, "%T", ((g_esPlayer[param1].g_iRewardVisuals & MT_VISUAL_SCREEN) ? "ScreenVisualOn" : "ScreenVisualOff"), param1);
					case 1: FormatEx(sMenuOption, sizeof sMenuOption, "%T", ((g_esPlayer[param1].g_iRewardVisuals & MT_VISUAL_PARTICLE) ? "ParticleVisualOn" : "ParticleVisualOff"), param1);
					case 2: FormatEx(sMenuOption, sizeof sMenuOption, "%T", ((g_esPlayer[param1].g_iRewardVisuals & MT_VISUAL_VOICELINE) ? "VoicelineVisualOn" : "VoicelineVisualOff"), param1);
					case 3: FormatEx(sMenuOption, sizeof sMenuOption, "%T", ((g_esPlayer[param1].g_iRewardVisuals & MT_VISUAL_VOICEPITCH) ? "PitchVisualOn" : "PitchVisualOff"), param1);
					case 4: FormatEx(sMenuOption, sizeof sMenuOption, "%T", ((g_esPlayer[param1].g_iRewardVisuals & MT_VISUAL_LIGHT) ? "LightVisualOn" : "LightVisualOff"), param1);
					case 5: FormatEx(sMenuOption, sizeof sMenuOption, "%T", ((g_esPlayer[param1].g_iRewardVisuals & MT_VISUAL_BODY) ? "BodyVisualOn" : "BodyVisualOff"), param1);
					case 6: FormatEx(sMenuOption, sizeof sMenuOption, "%T", ((g_esPlayer[param1].g_iRewardVisuals & MT_VISUAL_GLOW) ? "GlowVisualOn" : "GlowVisualOff"), param1);
				}

				return RedrawMenuItem(sMenuOption);
			}
		}
	}

	return 0;
}

void vTankMenu(int admin, bool adminmenu = false, int item = 0)
{
	char sIndex[5], sMenuItem[64], sTankName[33];
	Menu mTankMenu = new Menu(iTankMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display);
	mTankMenu.SetTitle("%s List", MT_CONFIG_SECTION_MAIN);

	switch (bIsTank(admin))
	{
		case true:
		{
			SetGlobalTransTarget(admin);
			FormatEx(sMenuItem, sizeof sMenuItem, "%T", "MTTankItem", admin, "MTDefaultItem", 0, 0);
			mTankMenu.AddItem("Default", sMenuItem, ((g_esPlayer[admin].g_iTankType > 0) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED));
		}
		case false:
		{
			for (int iIndex = -1; iIndex <= 0; iIndex++)
			{
				SetGlobalTransTarget(admin);
				FormatEx(sMenuItem, sizeof sMenuItem, "%T", "MTTankItem", admin, "NoName", iIndex, iIndex);
				IntToString(iIndex, sIndex, sizeof sIndex);
				mTankMenu.AddItem(sIndex, sMenuItem);
			}
		}
	}

	for (int iIndex = g_esGeneral.g_iMinType; iIndex <= g_esGeneral.g_iMaxType; iIndex++)
	{
		if (iIndex <= 0 || !bIsTankEnabled(iIndex) || !bHasCoreAdminAccess(admin, iIndex) || g_esTank[iIndex].g_iMenuEnabled == 0 || !bIsTypeAvailable(iIndex, admin) || bAreHumansRequired(iIndex) || !bCanTypeSpawn(iIndex) || !bIsRightGame(iIndex) || bIsAreaNarrow(admin, g_esTank[iIndex].g_flOpenAreasOnly) || bIsAreaWide(admin, g_esTank[iIndex].g_flCloseAreasOnly))
		{
			continue;
		}

		vGetTranslatedName(sTankName, sizeof sTankName, .type = iIndex);
		SetGlobalTransTarget(admin);
		FormatEx(sMenuItem, sizeof sMenuItem, "%T", "MTTankItem", admin, sTankName, iIndex, g_esTank[iIndex].g_iRealType[0]);
		IntToString(iIndex, sIndex, sizeof sIndex);
		mTankMenu.AddItem(sIndex, sMenuItem, ((g_esPlayer[admin].g_iTankType != iIndex) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED));
	}

	g_esPlayer[admin].g_bAdminMenu = adminmenu;
	mTankMenu.ExitBackButton = g_esPlayer[admin].g_bAdminMenu;
	mTankMenu.DisplayAt(admin, item, MENU_TIME_FOREVER);
}

int iTankMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Cancel:
		{
			if (g_esPlayer[param1].g_bAdminMenu)
			{
				g_esPlayer[param1].g_bAdminMenu = false;
#if defined _adminmenu_included
				if (bIsValidClient(param1, MT_CHECK_INGAME|MT_CHECK_FAKECLIENT|MT_CHECK_INKICKQUEUE) && param2 == MenuCancel_ExitBack && g_esGeneral.g_tmMTMenu != null)
				{
					g_esGeneral.g_tmMTMenu.Display(param1, TopMenuPosition_LastCategory);
				}
#endif
			}
		}
		case MenuAction_Select:
		{
			char sInfo[33];
			menu.GetItem(param2, sInfo, sizeof sInfo);
			int iIndex = StringToInt(sInfo);
			if (StrEqual(sInfo, "Default", false) && bIsTank(param1))
			{
				vQueueTank(param1, g_esPlayer[param1].g_iTankType, false);
			}
			else if (iIndex <= 0)
			{
				switch (iIndex)
				{
					case -1: vQueueTank(param1, iIndex, false);
					case 0: vSetupTankSpawn(param1, "random", false);
				}
			}
			else if (bIsTankEnabled(iIndex) && bHasCoreAdminAccess(param1, iIndex) && g_esTank[iIndex].g_iMenuEnabled == 1 && bIsTypeAvailable(iIndex, param1) && !bAreHumansRequired(iIndex) && bCanTypeSpawn(iIndex) && bIsRightGame(iIndex) && !bIsAreaNarrow(param1, g_esTank[iIndex].g_flOpenAreasOnly) && !bIsAreaWide(param1, g_esTank[iIndex].g_flCloseAreasOnly))
			{
				vQueueTank(param1, iIndex, false);
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME|MT_CHECK_FAKECLIENT|MT_CHECK_INKICKQUEUE))
			{
				vTankMenu(param1, g_esPlayer[param1].g_bAdminMenu, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pList = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "MTListMenu", param1);
			pList.SetTitle(sMenuTitle);
		}
	}

	return 0;
}

/**
 * Event functions & callbacks
 **/

void vEventHandler(Event event, const char[] name, bool dontBroadcast)
{
	if (g_esGeneral.g_bPluginEnabled)
	{
		if (StrEqual(name, "bot_player_replace"))
		{
			int iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId),
				iPlayerId = event.GetInt("player"), iPlayer = GetClientOfUserId(iPlayerId);
			if (bIsValidClient(iBot))
			{
				if (bIsTank(iPlayer))
				{
					vSetupTankControl(iBot, iPlayer);
				}
				else if (bIsSurvivor(iPlayer))
				{
					vRemoveSurvivorEffects(iBot);
					vSetupDeveloper(iPlayer, .usual = true);
					vCopySurvivorStats(iBot, iPlayer);
					vResetSurvivorStats(iBot, false);
					vToggleSurvivorEffects(iPlayer);
				}
			}
		}
		else if (StrEqual(name, "choke_start") || StrEqual(name, "lunge_pounce") || StrEqual(name, "tongue_grab") || StrEqual(name, "charger_carry_start") || StrEqual(name, "charger_pummel_start") || StrEqual(name, "jockey_ride"))
		{
			int iSpecialId = event.GetInt("userid"), iSpecial = GetClientOfUserId(iSpecialId),
				iSurvivorId = event.GetInt("victim"), iSurvivor = GetClientOfUserId(iSurvivorId);
			if (bIsSpecialInfected(iSpecial) && bIsSurvivor(iSurvivor) && (bIsDeveloper(iSurvivor, 11) || (g_esPlayer[iSurvivor].g_iRewardTypes & MT_REWARD_GODMODE)))
			{
				vSaveCaughtSurvivor(iSurvivor, iSpecial);
			}
		}
		else if (StrEqual(name, "create_panic_event"))
		{
			if (bIsSurvivalMode() && g_esGeneral.g_iSurvivalBlock == 0)
			{
				delete g_esGeneral.g_hSurvivalTimer;

				g_esGeneral.g_iSurvivalBlock = 1;
				g_esGeneral.g_hSurvivalTimer = CreateTimer(g_esGeneral.g_flSurvivalDelay, tTimerDelaySurvival);
			}
		}
		else if (StrEqual(name, "entity_shoved"))
		{
			int iSurvivorId = event.GetInt("attacker"), iSurvivor = GetClientOfUserId(iSurvivorId),
				iWitch = event.GetInt("entityid");
			if (bIsWitch(iWitch) && bIsSurvivor(iSurvivor))
			{
				bool bDeveloper = bIsDeveloper(iSurvivor, 9);
				if (bDeveloper || (g_esPlayer[iSurvivor].g_iRewardTypes & MT_REWARD_ATTACKBOOST))
				{
					float flMultiplier = (bDeveloper && g_esDeveloper[iSurvivor].g_flDevShoveDamage > g_esPlayer[iSurvivor].g_flShoveDamage) ? g_esDeveloper[iSurvivor].g_flDevShoveDamage : g_esPlayer[iSurvivor].g_flShoveDamage;
					if (flMultiplier > 0.0)
					{
						SDKHooks_TakeDamage(iWitch, iSurvivor, iSurvivor, (float(GetEntProp(iWitch, Prop_Data, "m_iMaxHealth")) * flMultiplier), DMG_CLUB);
					}
				}
			}
		}
		else if (StrEqual(name, "finale_escape_start") || StrEqual(name, "finale_vehicle_incoming") || StrEqual(name, "finale_vehicle_ready"))
		{
			g_esGeneral.g_iTankWave = 3;

			vExecuteFinaleConfigs(name);
		}
		else if (StrEqual(name, "finale_vehicle_leaving"))
		{
			g_esGeneral.g_bFinaleEnded = true;
			g_esGeneral.g_iTankWave = 4;

			vExecuteFinaleConfigs(name);
		}
		else if (StrEqual(name, "finale_rush") || StrEqual(name, "finale_radio_start") || StrEqual(name, "finale_radio_damaged") || StrEqual(name, "finale_bridge_lowering"))
		{
			vExecuteFinaleConfigs(name);
		}
		else if (StrEqual(name, "finale_start") || StrEqual(name, "gauntlet_finale_start"))
		{
			g_esGeneral.g_iTankWave = 1;

			vExecuteFinaleConfigs(name);
		}
		else if (StrEqual(name, "finale_win"))
		{
			vExecuteFinaleConfigs(name);
			vResetLadyKiller(true);
		}
		else if (StrEqual(name, "heal_success"))
		{
			int iSurvivorId = event.GetInt("subject"), iSurvivor = GetClientOfUserId(iSurvivorId);
			if (bIsSurvivor(iSurvivor))
			{
				g_esPlayer[iSurvivor].g_bLastLife = false;
				g_esPlayer[iSurvivor].g_iReviveCount = 0;
			}
		}
		else if (StrEqual(name, "infected_hurt"))
		{
			int iSurvivorId = event.GetInt("attacker"), iSurvivor = GetClientOfUserId(iSurvivorId),
				iWitch = event.GetInt("entityid"), iDamageType = event.GetInt("type");
			if (bIsSurvivor(iSurvivor) && bIsWitch(iWitch) && !g_esGeneral.g_bWitchKilled[iWitch])
			{
				bool bDeveloper = bIsDeveloper(iSurvivor, 11);
				if (bDeveloper || (g_esPlayer[iSurvivor].g_iLadyKillerCount < g_esPlayer[iSurvivor].g_iLadyKillerLimit))
				{
					g_esGeneral.g_bWitchKilled[iWitch] = true;

					SDKHooks_TakeDamage(iWitch, iSurvivor, iSurvivor, float(GetEntProp(iWitch, Prop_Data, "m_iHealth")), iDamageType);
					EmitSoundToClient(iSurvivor, SOUND_LADYKILLER, iSurvivor, SNDCHAN_AUTO, SNDLEVEL_NORMAL);

					if (!bDeveloper)
					{
						g_esPlayer[iSurvivor].g_iLadyKillerCount++;

						MT_PrintToChat(iSurvivor, "%s %t", MT_TAG2, "RewardLadyKiller2", (g_esPlayer[iSurvivor].g_iLadyKillerLimit - g_esPlayer[iSurvivor].g_iLadyKillerCount));
					}
				}
			}
		}
		else if (StrEqual(name, "mission_lost") || StrEqual(name, "round_end"))
		{
			vResetRound();
		}
		else if (StrEqual(name, "player_bot_replace"))
		{
			int iPlayerId = event.GetInt("player"), iPlayer = GetClientOfUserId(iPlayerId),
				iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId);
			if (bIsValidClient(iPlayer))
			{
				if (bIsTank(iBot))
				{
					vSetupTankControl(iPlayer, iBot);
				}
				else if (bIsSurvivor(iBot))
				{
					vRemoveSurvivorEffects(iPlayer);
					vSetupDeveloper(iPlayer, false);
					vCopySurvivorStats(iPlayer, iBot);
					vResetSurvivorStats(iPlayer, false);
					vToggleSurvivorEffects(iBot);
				}
			}
		}
		else if (StrEqual(name, "player_connect") || StrEqual(name, "player_disconnect"))
		{
			int iSurvivorId = event.GetInt("userid"), iSurvivor = GetClientOfUserId(iSurvivorId);
			vInitialReset(iSurvivor);
			vDeveloperSettings(iSurvivor);
			vResetTank2(iSurvivor);
		}
		else if (StrEqual(name, "player_death"))
		{
			int iVictimId = event.GetInt("userid"), iVictim = GetClientOfUserId(iVictimId),
				iAttackerId = event.GetInt("attacker"), iAttacker = GetClientOfUserId(iAttackerId);
			if (bIsTank(iVictim, MT_CHECK_INDEX|MT_CHECK_INGAME))
			{
				g_esPlayer[iVictim].g_bDied = true;

				SDKUnhook(iVictim, SDKHook_PostThinkPost, OnTankPostThinkPost);
				vCalculateDeath(iVictim, iAttacker);

				if (g_esPlayer[iVictim].g_iTankType > 0)
				{
					if (g_esCache[iVictim].g_iDeathRevert == 1)
					{
						int iType = g_esPlayer[iVictim].g_iTankType;
						vSetTankColor(iVictim, .revert = true);
						g_esPlayer[iVictim].g_iTankType = iType;
					}

					vResetTank(iVictim, g_esCache[iVictim].g_iDeathRevert);
					CreateTimer(1.0, tTimerResetType, iVictimId, TIMER_FLAG_NO_MAPCHANGE);
				}

				int iCount = iGetTankCount(true);
				if (iCount == 0)
				{
					vResetTimers();
				}
			}
			else if (bIsSurvivor(iVictim, MT_CHECK_INDEX|MT_CHECK_INGAME))
			{
				if (bIsTank(iAttacker, MT_CHECK_INDEX|MT_CHECK_INGAME))
				{
					g_esPlayer[iAttacker].g_iKillCount++;

					if (g_esCache[iAttacker].g_iAnnounceKill == 1)
					{
						int iOption = iGetMessageType(g_esCache[iAttacker].g_iKillMessage);
						if (iOption > 0)
						{
							char sPhrase[32], sTankName[33];
							FormatEx(sPhrase, sizeof sPhrase, "Kill%i", iOption);
							vGetTranslatedName(sTankName, sizeof sTankName, iAttacker);
							MT_PrintToChatAll("%s %t", MT_TAG2, sPhrase, sTankName, iVictim);
							vLogMessage(MT_LOG_LIFE, _, "%s %T", MT_TAG, sPhrase, LANG_SERVER, sTankName, iVictim);
						}
					}
				}

				vRemoveSurvivorEffects(iVictim, true);
			}
		}
		else if (StrEqual(name, "player_hurt"))
		{
			int iVictimId = event.GetInt("userid"), iVictim = GetClientOfUserId(iVictimId),
				iAttackerId = event.GetInt("attacker"), iAttacker = GetClientOfUserId(iAttackerId);
			if (bIsTank(iVictim) && !bIsPlayerIncapacitated(iVictim) && bIsSurvivor(iAttacker))
			{
				g_esPlayer[iAttacker].g_iTankDamage[iVictim] += event.GetInt("dmg_health");
			}
		}
		else if (StrEqual(name, "player_incapacitated"))
		{
			int iVictimId = event.GetInt("userid"), iVictim = GetClientOfUserId(iVictimId);
			if (bIsTank(iVictim, MT_CHECK_INDEX|MT_CHECK_INGAME))
			{
				g_esPlayer[iVictim].g_bDied = false;

				CreateTimer(10.0, tTimerKillStuckTank, iVictimId, TIMER_FLAG_NO_MAPCHANGE);
				vCombineAbilitiesForward(iVictim, MT_COMBO_UPONINCAP);
			}
			else if (bIsSurvivor(iVictim))
			{
				int iAttackerId = event.GetInt("attacker"), iAttacker = GetClientOfUserId(iAttackerId);
				if (bIsTank(iAttacker, MT_CHECK_INDEX|MT_CHECK_INGAME))
				{
					g_esPlayer[iAttacker].g_iIncapCount++;
				}
			}
		}
		else if (StrEqual(name, "player_now_it"))
		{
			int iPlayerId = event.GetInt("userid"), iPlayer = GetClientOfUserId(iPlayerId);
			if (bIsTank(iPlayer) || bIsSurvivor(iPlayer))
			{
				vRemovePlayerGlow(iPlayer);
			}

			if (bIsValidClient(iPlayer, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE) && !g_esPlayer[iPlayer].g_bVomited)
			{
				g_esPlayer[iPlayer].g_bVomited = true;
			}
		}
		else if (StrEqual(name, "player_no_longer_it"))
		{
			int iPlayerId = event.GetInt("userid"), iPlayer = GetClientOfUserId(iPlayerId);
			vRestorePlayerGlow(iPlayer);

			if (bIsValidClient(iPlayer, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE) && g_esPlayer[iPlayer].g_bVomited)
			{
				g_esPlayer[iPlayer].g_bVomited = false;
			}
		}
		else if (StrEqual(name, "player_shoved"))
		{
			int iSpecialId = event.GetInt("userid"), iSpecial = GetClientOfUserId(iSpecialId),
				iSurvivorId = event.GetInt("attacker"), iSurvivor = GetClientOfUserId(iSurvivorId);
			if ((bIsTank(iSpecial) || bIsCharger(iSpecial)) && bIsSurvivor(iSurvivor))
			{
				bool bDeveloper = bIsDeveloper(iSurvivor, 9);
				if (bDeveloper || (g_esPlayer[iSurvivor].g_iRewardTypes & MT_REWARD_ATTACKBOOST))
				{
					float flMultiplier = (bDeveloper && g_esDeveloper[iSurvivor].g_flDevShoveDamage > g_esPlayer[iSurvivor].g_flShoveDamage) ? g_esDeveloper[iSurvivor].g_flDevShoveDamage : g_esPlayer[iSurvivor].g_flShoveDamage;
					if (flMultiplier > 0.0)
					{
						vDamagePlayer(iSpecial, iSurvivor, (float(GetEntProp(iSpecial, Prop_Data, "m_iMaxHealth")) * flMultiplier), "128");
					}
				}
			}
		}
		else if (StrEqual(name, "player_spawn"))
		{
			int iPlayerId = event.GetInt("userid"), iPlayer = GetClientOfUserId(iPlayerId);
			if (bIsValidClient(iPlayer))
			{
				SDKUnhook(iPlayer, SDKHook_PostThinkPost, OnTankPostThinkPost);

				int iType = (g_esPlayer[iPlayer].g_iPersonalType > 0) ? g_esPlayer[iPlayer].g_iPersonalType : g_esGeneral.g_iChosenType;
				DataPack dpPlayerSpawn = new DataPack();
				dpPlayerSpawn.WriteCell(iPlayerId);
				dpPlayerSpawn.WriteCell(iType);
				RequestFrame(vPlayerSpawnFrame, dpPlayerSpawn);
			}
		}
		else if (StrEqual(name, "player_team"))
		{
			int iPlayerId = event.GetInt("userid"), iPlayer = GetClientOfUserId(iPlayerId);
			if (bIsValidClient(iPlayer))
			{
				vRemoveSurvivorEffects(iPlayer);
			}
		}
		else if (StrEqual(name, "revive_success"))
		{
			int iSurvivorId = event.GetInt("subject"), iSurvivor = GetClientOfUserId(iSurvivorId);
			if (bIsSurvivor(iSurvivor))
			{
				g_esPlayer[iSurvivor].g_bLastLife = event.GetBool("lastlife");
				g_esPlayer[iSurvivor].g_iReviveCount++;
				g_esPlayer[iSurvivor].g_iReviver = 0;
			}
		}
		else if (StrEqual(name, "round_start"))
		{
			g_esGeneral.g_bNextRound = !!GameRules_GetProp("m_bInSecondHalfOfRound");

			vResetRound();
		}
		else if (StrEqual(name, "weapon_given"))
		{
			int iSurvivorId = event.GetInt("userid"), iSurvivor = GetClientOfUserId(iSurvivorId),
				iWeapon = event.GetInt("weapon");
			if (bIsSurvivor(iSurvivor) && (bIsDeveloper(iSurvivor, 6) || (g_esPlayer[iSurvivor].g_iRewardTypes & MT_REWARD_ATTACKBOOST)) && (iWeapon == 15 || iWeapon == 23))
			{
				SDKHook(iSurvivor, SDKHook_WeaponCanSwitchTo, OnWeaponCanSwitchTo);
			}
		}
		else if (StrEqual(name, "witch_harasser_set"))
		{
			int iHarasserId = event.GetInt("userid"), iHarasser = GetClientOfUserId(iHarasserId);
			for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
			{
				if (bIsSurvivor(iSurvivor) && g_esPlayer[iSurvivor].g_iLadyKillerLimit > 0 && iSurvivor != iHarasser)
				{
					MT_PrintToChat(iSurvivor, "%s %t", MT_TAG2, "RewardLadyKiller2", (g_esPlayer[iSurvivor].g_iLadyKillerLimit - g_esPlayer[iSurvivor].g_iLadyKillerCount));
				}
			}
		}
		else if (StrEqual(name, "witch_killed"))
		{
			int iWitch = event.GetInt("witchid");
			g_esGeneral.g_bWitchKilled[iWitch] = false;
		}

		Call_StartForward(g_esGeneral.g_gfEventFiredForward);
		Call_PushCell(event);
		Call_PushString(name);
		Call_PushCell(dontBroadcast);
		Call_Finish();
	}
}

void vHookEvents(bool hook)
{
	static bool bHooked, bCheck[38];
	if (hook && !bHooked)
	{
		bHooked = true;

		bCheck[0] = HookEventEx("bot_player_replace", vEventHandler);
		bCheck[1] = HookEventEx("choke_start", vEventHandler);
		bCheck[2] = HookEventEx("create_panic_event", vEventHandler);
		bCheck[3] = HookEventEx("entity_shoved", vEventHandler);
		bCheck[4] = HookEventEx("finale_escape_start", vEventHandler);
		bCheck[5] = HookEventEx("finale_start", vEventHandler, EventHookMode_Pre);
		bCheck[6] = HookEventEx("finale_vehicle_leaving", vEventHandler);
		bCheck[7] = HookEventEx("finale_vehicle_ready", vEventHandler);
		bCheck[8] = HookEventEx("finale_rush", vEventHandler);
		bCheck[9] = HookEventEx("finale_radio_start", vEventHandler);
		bCheck[10] = HookEventEx("finale_radio_damaged", vEventHandler);
		bCheck[11] = HookEventEx("finale_win", vEventHandler);
		bCheck[12] = HookEventEx("heal_success", vEventHandler);
		bCheck[13] = HookEventEx("infected_hurt", vEventHandler);
		bCheck[14] = HookEventEx("lunge_pounce", vEventHandler);
		bCheck[15] = HookEventEx("mission_lost", vEventHandler);
		bCheck[16] = HookEventEx("player_bot_replace", vEventHandler);
		bCheck[17] = HookEventEx("player_connect", vEventHandler, EventHookMode_Pre);
		bCheck[18] = HookEventEx("player_death", vEventHandler, EventHookMode_Pre);
		bCheck[19] = HookEventEx("player_disconnect", vEventHandler, EventHookMode_Pre);
		bCheck[20] = HookEventEx("player_hurt", vEventHandler);
		bCheck[21] = HookEventEx("player_incapacitated", vEventHandler);
		bCheck[22] = HookEventEx("player_now_it", vEventHandler);
		bCheck[23] = HookEventEx("player_no_longer_it", vEventHandler);
		bCheck[24] = HookEventEx("player_shoved", vEventHandler);
		bCheck[25] = HookEventEx("player_spawn", vEventHandler);
		bCheck[26] = HookEventEx("player_team", vEventHandler);
		bCheck[27] = HookEventEx("revive_success", vEventHandler);
		bCheck[28] = HookEventEx("tongue_grab", vEventHandler);
		bCheck[29] = HookEventEx("weapon_given", vEventHandler);
		bCheck[30] = HookEventEx("witch_harasser_set", vEventHandler);
		bCheck[31] = HookEventEx("witch_killed", vEventHandler);

		if (g_bSecondGame)
		{
			bCheck[32] = HookEventEx("charger_carry_start", vEventHandler);
			bCheck[33] = HookEventEx("charger_pummel_start", vEventHandler);
			bCheck[34] = HookEventEx("finale_vehicle_incoming", vEventHandler);
			bCheck[35] = HookEventEx("finale_bridge_lowering", vEventHandler);
			bCheck[36] = HookEventEx("gauntlet_finale_start", vEventHandler);
			bCheck[37] = HookEventEx("jockey_ride", vEventHandler);
		}

		vHookEventForward(true);
		vHookUserMessage(true);
	}
	else if (!hook && bHooked)
	{
		bHooked = false;
		bool bPreHook[38];
		char sEvent[32];

		for (int iPos = 0; iPos < (sizeof bCheck); iPos++)
		{
			switch (iPos)
			{
				case 0: sEvent = "bot_player_replace";
				case 1: sEvent = "choke_start";
				case 2: sEvent = "create_panic_event";
				case 3: sEvent = "entity_shoved";
				case 4: sEvent = "finale_escape_start";
				case 5: sEvent = "finale_start";
				case 6: sEvent = "finale_vehicle_leaving";
				case 7: sEvent = "finale_vehicle_ready";
				case 8: sEvent = "finale_rush";
				case 9: sEvent = "finale_radio_start";
				case 10: sEvent = "finale_radio_damaged";
				case 11: sEvent = "finale_win";
				case 12: sEvent = "heal_success";
				case 13: sEvent = "infected_hurt";
				case 14: sEvent = "lunge_pounce";
				case 15: sEvent = "mission_lost";
				case 16: sEvent = "player_bot_replace";
				case 17: sEvent = "player_connect";
				case 18: sEvent = "player_death";
				case 19: sEvent = "player_disconnect";
				case 20: sEvent = "player_hurt";
				case 21: sEvent = "player_incapacitated";
				case 22: sEvent = "player_now_it";
				case 23: sEvent = "player_no_longer_it";
				case 24: sEvent = "player_shoved";
				case 25: sEvent = "player_spawn";
				case 26: sEvent = "player_team";
				case 27: sEvent = "revive_success";
				case 28: sEvent = "tongue_grab";
				case 29: sEvent = "weapon_given";
				case 30: sEvent = "witch_harasser_set";
				case 31: sEvent = "witch_killed";
				case 32: sEvent = "charger_carry_start";
				case 33: sEvent = "charger_pummel_start";
				case 34: sEvent = "finale_vehicle_incoming";
				case 35: sEvent = "finale_bridge_lowering";
				case 36: sEvent = "gauntlet_finale_start";
				case 37: sEvent = "jockey_ride";
			}

			if (bCheck[iPos])
			{
				if (!g_bSecondGame && iPos >= 32 && iPos <= 37)
				{
					continue;
				}

				bCheck[iPos] = false;
				bPreHook[iPos] = (iPos == 5) || (iPos >= 17 && iPos <= 19);

				UnhookEvent(sEvent, vEventHandler, (bPreHook[iPos] ? EventHookMode_Pre : EventHookMode_Post));
			}
		}

		vHookEventForward(false);
		vHookUserMessage(false);
	}
}

void vHookGlobalEvents()
{
	HookEvent("round_start", vEventHandler);
	HookEvent("round_end", vEventHandler);
}

/**
 * Game Data functions
 **/

void vReadGameData()
{
	g_esGeneral.g_gdMutantTanks = new GameData(MT_GAMEDATA);

	switch (g_esGeneral.g_gdMutantTanks == null)
	{
		case true: SetFailState("Unable to load the \"%s\" gamedata file.", MT_GAMEDATA);
		case false:
		{
			g_esGeneral.g_iPlatformType = iGetGameDataOffset("OS");
			if (g_esGeneral.g_iPlatformType == 0)
			{
				vRegisterSignatures();
				vSetupSignatureAddresses();
				vSetupSignatures();
			}

			if (g_bSecondGame)
			{
				g_esGeneral.g_hSDKGetUseAction = hGetSimpleSDKCall(g_esGeneral.g_gdMutantTanks, SDKCall_Entity, SDKConf_Virtual, .name = "CBaseBackpackItem::GetUseAction");
				g_esGeneral.g_hSDKHasConfigurableDifficultySetting = hGetSimpleSDKCall(g_esGeneral.g_gdMutantTanks, SDKCall_GameRules, SDKConf_Signature, .returnType = SDKType_Bool, .name = "CTerrorGameRules::HasConfigurableDifficultySetting");
				g_esGeneral.g_hSDKIsFirstMapInScenario = hGetSimpleSDKCall(g_esGeneral.g_gdMutantTanks, SDKCall_Raw, SDKConf_Signature, .returnType = SDKType_Bool, .name = "CDirector::IsFirstMapInScenario", .dynamicSig = true, .signature = "MTSignature_IsFirstMapInScenario");
				g_esGeneral.g_hSDKIsInStasis = hGetSimpleSDKCall(g_esGeneral.g_gdMutantTanks, SDKCall_Player, SDKConf_Virtual, .returnType = SDKType_Bool, .name = "CBaseEntity::IsInStasis");
				g_esGeneral.g_hSDKIsRealismMode = hGetSimpleSDKCall(g_esGeneral.g_gdMutantTanks, SDKCall_GameRules, SDKConf_Signature, .returnType = SDKType_Bool, .name = "CTerrorGameRules::IsRealismMode", .dynamicSig = true, .signature = "MTSignature_IsRealismMode");
				g_esGeneral.g_hSDKIsScavengeMode = hGetSimpleSDKCall(g_esGeneral.g_gdMutantTanks, SDKCall_GameRules, SDKConf_Signature, .returnType = SDKType_Bool, .name = "CTerrorGameRules::IsScavengeMode", .dynamicSig = true, .signature = "MTSignature_IsScavengeMode");
				g_esGeneral.g_iMeleeOffset = iGetGameDataOffset("CTerrorPlayer::OnIncapacitatedAsSurvivor::HiddenMeleeWeapon");
			}

			g_esGeneral.g_adDirector = adGetGameDataAddress("CDirector");
			g_esGeneral.g_adDoJumpValue = adGetCombinedGameDataAddress("CTerrorGameMovement::DoJump::Value", "DoJumpValueRead", "PlayerLocomotion::GetMaxJumpHeight", "PlayerLocomotion::GetMaxJumpHeight::Call", "PlayerLocomotion::GetMaxJumpHeight::Add", "PlayerLocomotion::GetMaxJumpHeight::Value");
			g_esGeneral.g_hSDKGetRefEHandle = hGetSimpleSDKCall(g_esGeneral.g_gdMutantTanks, SDKCall_Raw, SDKConf_Virtual, .name = "CBaseEntity::GetRefEHandle");
			g_esGeneral.g_hSDKHasAnySurvivorLeftSafeArea = hGetSimpleSDKCall(g_esGeneral.g_gdMutantTanks, SDKCall_Raw, SDKConf_Signature, .returnType = SDKType_Bool, .name = "CDirector::HasAnySurvivorLeftSafeArea");
			g_esGeneral.g_hSDKGetWeaponID = hGetSimpleSDKCall(g_esGeneral.g_gdMutantTanks, SDKCall_Entity, SDKConf_Virtual, .name = "CPainPills::GetWeaponID");
			g_esGeneral.g_hSDKRockDetonate = hGetSimpleSDKCall(g_esGeneral.g_gdMutantTanks, SDKCall_Entity, SDKConf_Signature, false, .name = "CTankRock::Detonate");
			g_esGeneral.g_hSDKGetMissionInfo = hGetSimpleSDKCall(g_esGeneral.g_gdMutantTanks, SDKCall_GameRules, SDKConf_Signature, .name = "CTerrorGameRules::GetMissionInfo");
			g_esGeneral.g_hSDKIsCoopMode = hGetSimpleSDKCall(g_esGeneral.g_gdMutantTanks, SDKCall_GameRules, SDKConf_Signature, .returnType = SDKType_Bool, .name = "CTerrorGameRules::IsCoopMode", .dynamicSig = true, .signature = "MTSignature_IsCoopMode");
			g_esGeneral.g_hSDKIsMissionFinalMap = hGetSimpleSDKCall(g_esGeneral.g_gdMutantTanks, SDKCall_GameRules, SDKConf_Signature, .returnType = SDKType_Bool, .name = "CTerrorGameRules::IsMissionFinalMap", .dynamicSig = true, .signature = "MTSignature_IsMissionFinalMap");
			g_esGeneral.g_hSDKIsSurvivalMode = hGetSimpleSDKCall(g_esGeneral.g_gdMutantTanks, SDKCall_GameRules, SDKConf_Signature, .returnType = SDKType_Bool, .name = "CTerrorGameRules::IsSurvivalMode", .dynamicSig = true, .signature = "MTSignature_IsSurvivalMode");
			g_esGeneral.g_hSDKIsVersusMode = hGetSimpleSDKCall(g_esGeneral.g_gdMutantTanks, SDKCall_GameRules, SDKConf_Signature, .returnType = SDKType_Bool, .name = "CTerrorGameRules::IsVersusMode", .dynamicSig = true, .signature = "MTSignature_IsVersusMode");
			g_esGeneral.g_hSDKITExpired = hGetSimpleSDKCall(g_esGeneral.g_gdMutantTanks, SDKCall_Player, SDKConf_Signature, false, .name = "CTerrorPlayer::OnITExpired");
			g_esGeneral.g_hSDKMaterializeFromGhost = hGetSimpleSDKCall(g_esGeneral.g_gdMutantTanks, SDKCall_Player, SDKConf_Signature, .name = "CTerrorPlayer::MaterializeFromGhost", .dynamicSig = true, .signature = "MTSignature_MaterializeFromGhost");
			g_esGeneral.g_hSDKRevive = hGetSimpleSDKCall(g_esGeneral.g_gdMutantTanks, SDKCall_Player, SDKConf_Signature, false, .name = "CTerrorPlayer::OnRevived");
			g_esGeneral.g_hSDKRoundRespawn = hGetSimpleSDKCall(g_esGeneral.g_gdMutantTanks, SDKCall_Player, SDKConf_Signature, false, .name = "CTerrorPlayer::RoundRespawn");
			g_esGeneral.g_hSDKLeaveStasis = hGetSimpleSDKCall(g_esGeneral.g_gdMutantTanks, SDKCall_Player, SDKConf_Signature, .name = "Tank::LeaveStasis");
			g_esGeneral.g_iAttackerOffset = iGetGameDataOffset("CTerrorPlayer::Event_Killed::Attacker");
			g_esGeneral.g_iIntentionOffset = iGetGameDataOffset("Tank::GetIntentionInterface::Intention");
			g_esGeneral.g_iVerticalPunchOffset = iGetGameDataOffset("CTerrorWeaponInfo::Parse::VerticalPunch");

			StartPrepSDKCall(SDKCall_Static);

			int iIndex = iGetSignatureIndex("MTSignature_GetMissionFirstMap");
			if (iIndex == -1 || g_esGeneral.g_iPlatformType > 0)
			{
				if (!PrepSDKCall_SetFromConf(g_esGeneral.g_gdMutantTanks, SDKConf_Signature, "CTerrorGameRules::GetMissionFirstMap"))
				{
					LogError("%s Failed to find signature: CTerrorGameRules::GetMissionFirstMap", MT_TAG);
				}
			}
			else
			{
				char sSignature[1024];
				int iCount = 0;
				vGetBinariesFromSignature(g_esSignature[iIndex].g_sDynamicSig, sSignature, sizeof sSignature, iCount);
				if (!PrepSDKCall_SetSignature(g_esSignature[iIndex].g_sdkLibrary, sSignature, iCount))
				{
					LogError("%s Failed to find dynamic signature: MTSignature_GetMissionFirstMap", MT_TAG);

					if (!PrepSDKCall_SetFromConf(g_esGeneral.g_gdMutantTanks, SDKConf_Signature, "CTerrorGameRules::GetMissionFirstMap"))
					{
						LogError("%s Failed to find signature: CTerrorGameRules::GetMissionFirstMap", MT_TAG);
					}
				}
			}

			PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain, VDECODE_FLAG_ALLOWWORLD);
			PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
			g_esGeneral.g_hSDKGetMissionFirstMap = EndPrepSDKCall();
			if (g_esGeneral.g_hSDKGetMissionFirstMap == null)
			{
				LogError("%s Your \"CTerrorGameRules::GetMissionFirstMap\" signature is outdated.", MT_TAG);
			}

			StartPrepSDKCall(SDKCall_Player);
			if (!PrepSDKCall_SetFromConf(g_esGeneral.g_gdMutantTanks, SDKConf_Virtual, "CTerrorPlayer::Deafen"))
			{
				LogError("%s Failed to load offset: CTerrorPlayer::Deafen", MT_TAG);
			}

			PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
			PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
			PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);

			g_esGeneral.g_hSDKDeafen = EndPrepSDKCall();
			if (g_esGeneral.g_hSDKDeafen == null)
			{
				LogError("%s Your \"CTerrorPlayer::Deafen\" offsets are outdated.", MT_TAG);
			}

			StartPrepSDKCall(SDKCall_Player);
			if (!PrepSDKCall_SetFromConf(g_esGeneral.g_gdMutantTanks, SDKConf_Signature, "CTerrorPlayer::OnShovedBySurvivor"))
			{
				LogError("%s Failed to find signature: CTerrorPlayer::OnShovedBySurvivor", MT_TAG);
			}

			PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
			PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
			g_esGeneral.g_hSDKShovedBySurvivor = EndPrepSDKCall();
			if (g_esGeneral.g_hSDKShovedBySurvivor == null)
			{
				LogError("%s Your \"CTerrorPlayer::OnShovedBySurvivor\" signature is outdated.", MT_TAG);
			}

			StartPrepSDKCall(SDKCall_Player);
			if (!PrepSDKCall_SetFromConf(g_esGeneral.g_gdMutantTanks, SDKConf_Signature, "CTerrorPlayer::OnStaggered"))
			{
				LogError("%s Failed to find signature: CTerrorPlayer::OnStaggered", MT_TAG);
			}

			PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
			PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Pointer);
			g_esGeneral.g_hSDKStagger = EndPrepSDKCall();
			if (g_esGeneral.g_hSDKStagger == null)
			{
				LogError("%s Your \"CTerrorPlayer::OnStaggered\" signature is outdated.", MT_TAG);
			}

			StartPrepSDKCall(SDKCall_Player);
			if (!PrepSDKCall_SetFromConf(g_esGeneral.g_gdMutantTanks, SDKConf_Signature, "CTerrorPlayer::OnVomitedUpon"))
			{
				LogError("%s Failed to find signature: CTerrorPlayer::OnVomitedUpon", MT_TAG);
			}

			PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
			PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
			if (!g_bSecondGame)
			{
				PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
			}

			g_esGeneral.g_hSDKVomitedUpon = EndPrepSDKCall();
			if (g_esGeneral.g_hSDKVomitedUpon == null)
			{
				LogError("%s Your \"CTerrorPlayer::OnVomitedUpon\" signature is outdated.", MT_TAG);
			}

			StartPrepSDKCall(SDKCall_Static);
			if (!PrepSDKCall_SetFromConf(g_esGeneral.g_gdMutantTanks, SDKConf_Signature, "GetWeaponInfo"))
			{
				LogError("%s Failed to find signature: GetWeaponInfo", MT_TAG);
			}

			PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
			PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
			g_esGeneral.g_hSDKGetWeaponInfo = EndPrepSDKCall();
			if (g_esGeneral.g_hSDKGetWeaponInfo == null)
			{
				LogError("%s Your \"GetWeaponInfo\" signature is outdated.", MT_TAG);
			}

			StartPrepSDKCall(SDKCall_Raw);
			if (!PrepSDKCall_SetFromConf(g_esGeneral.g_gdMutantTanks, SDKConf_Signature, "KeyValues::GetString"))
			{
				LogError("%s Failed to find signature: KeyValues::GetString", MT_TAG);
			}

			PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
			PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
			PrepSDKCall_SetReturnInfo(SDKType_String, SDKPass_Pointer);
			g_esGeneral.g_hSDKKeyValuesGetString = EndPrepSDKCall();
			if (g_esGeneral.g_hSDKKeyValuesGetString == null)
			{
				LogError("%s Your \"KeyValues::GetString\" signature is outdated.", MT_TAG);
			}

			int iOffset = iGetGameDataOffset("Action<Tank>::FirstContainedResponder");
			StartPrepSDKCall(SDKCall_Raw);
			PrepSDKCall_SetVirtual(iOffset);
			PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
			g_esGeneral.g_hSDKFirstContainedResponder = EndPrepSDKCall();
			if (g_esGeneral.g_hSDKFirstContainedResponder == null)
			{
				LogError("%s Your \"Action<Tank>::FirstContainedResponder\" offsets are outdated.", MT_TAG);
			}

			iOffset = iGetGameDataOffset("CBaseCombatWeapon::GetMaxClip1");
			StartPrepSDKCall(SDKCall_Entity);
			PrepSDKCall_SetVirtual(iOffset);
			PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_ByValue);
			g_esGeneral.g_hSDKGetMaxClip1 = EndPrepSDKCall();
			if (g_esGeneral.g_hSDKGetMaxClip1 == null)
			{
				LogError("%s Your \"CBaseCombatWeapon::GetMaxClip1\" offsets are outdated.", MT_TAG);
			}

			iOffset = iGetGameDataOffset("TankIdle::GetName");
			StartPrepSDKCall(SDKCall_Raw);
			PrepSDKCall_SetVirtual(iOffset);
			PrepSDKCall_SetReturnInfo(SDKType_String, SDKPass_Plain);
			g_esGeneral.g_hSDKGetName = EndPrepSDKCall();
			if (g_esGeneral.g_hSDKGetName == null)
			{
				LogError("%s Your \"TankIdle::GetName\" offsets are outdated.", MT_TAG);
			}
		}
	}
}

Handle hGetSimpleSDKCall(GameData dataHandle, SDKCallType callType, SDKFuncConfSource source, bool setType = true, SDKType returnType = SDKType_PlainOldData, SDKPassMethod method = SDKPass_Plain, const char[] name, bool dynamicSig = false, const char[] signature = "")
{
	StartPrepSDKCall(callType);
	if (dynamicSig && g_esGeneral.g_iPlatformType == 0)
	{
		int iIndex = iGetSignatureIndex(signature);
		if (iIndex == -1)
		{
			if (!PrepSDKCall_SetFromConf(dataHandle, source, name))
			{
				LogError("%s Failed to find signature: %s", MT_TAG, name);
			}
		}
		else
		{
			char sSignature[1024];
			int iCount = 0;
			vGetBinariesFromSignature(g_esSignature[iIndex].g_sDynamicSig, sSignature, sizeof sSignature, iCount);
			if (!PrepSDKCall_SetSignature(g_esSignature[iIndex].g_sdkLibrary, sSignature, iCount))
			{
				LogError("%s Failed to find dynamic signature: %s", MT_TAG, signature);

				if (!PrepSDKCall_SetFromConf(dataHandle, source, name))
				{
					LogError("%s Failed to find signature: %s", MT_TAG, name);
				}
			}
		}
	}
	else if (!PrepSDKCall_SetFromConf(dataHandle, source, name))
	{
		LogError("%s Failed to find signature: %s", MT_TAG, name);
	}

	if (setType)
	{
		PrepSDKCall_SetReturnInfo(returnType, method);
	}

	Handle hSDKCall = EndPrepSDKCall();
	if (hSDKCall == null)
	{
		LogError("%s Your \"%s\" signature is outdated.", MT_TAG, name);
	}

	return hSDKCall;
}

Address adGetCombinedGameDataAddress(const char[] name, const char[] backup, const char[] start, const char[] offset1, const char[] offset2, const char[] offset3)
{
	Address adResult = g_esGeneral.g_gdMutantTanks.GetMemSig(name);
	if (adResult == Address_Null)
	{
		LogError("%s Failed to find address from \"%s\". Retrieving from \"%s\" instead.", MT_TAG, name, backup);

		if (g_bSecondGame || g_esGeneral.g_iPlatformType < 2)
		{
			adResult = g_esGeneral.g_gdMutantTanks.GetAddress(backup);
			if (adResult == Address_Null)
			{
				LogError("%s Failed to find address from \"%s\". Failed to retrieve address from both methods.", MT_TAG, backup);
			}
		}
		else
		{
			Address adValue[4] = {Address_Null, Address_Null, Address_Null, Address_Null};
			adValue[0] = g_esGeneral.g_gdMutantTanks.GetMemSig(start);

			int iOffset[3] = {-1, -1, -1};
			iOffset[0] = iGetGameDataOffset(offset1);
			iOffset[1] = iGetGameDataOffset(offset2);
			iOffset[2] = iGetGameDataOffset(offset3);

			if (adValue[0] == Address_Null || iOffset[0] == -1 || iOffset[1] == -1 || iOffset[2] == -1)
			{
				LogError("%s Failed to find address from \"%s\". Failed to retrieve address from both methods.", MT_TAG, backup);
			}
			else
			{
				adValue[1] = adValue[0] + view_as<Address>(iOffset[0]);
				adValue[2] = LoadFromAddress((adValue[0] + view_as<Address>(iOffset[1])), NumberType_Int32);
				adValue[3] = LoadFromAddress((adValue[0] + view_as<Address>(iOffset[2])), NumberType_Int32);
				adResult = (adValue[1] + adValue[2] + adValue[3]);
			}
		}
	}

	return adResult;
}

Address adGetGameDataAddress(const char[] name)
{
	Address adAddress = g_esGeneral.g_gdMutantTanks.GetAddress(name);
	if (adAddress == Address_Null)
	{
		LogError("%s Failed to find address: %s", MT_TAG, name);
	}

	return adAddress;
}

int iGetGameDataOffset(const char[] name)
{
	int iOffset = g_esGeneral.g_gdMutantTanks.GetOffset(name);
	if (iOffset == -1)
	{
		LogError("%s Failed to load offset: %s", MT_TAG, name);
	}

	return iOffset;
}

/**
 * Forward functions
 **/

void vChangeTypeForward(int tank, int oldType, int newType, bool revert)
{
	Call_StartForward(g_esGeneral.g_gfChangeTypeForward);
	Call_PushCell(tank);
	Call_PushCell(oldType);
	Call_PushCell(newType);
	Call_PushCell(revert);
	Call_Finish();
}

void vCombineAbilitiesForward(int tank, int type, int survivor = 0, int weapon = 0, const char[] classname = "")
{
	if (bIsTankSupported(tank) && bIsCustomTankSupported(tank) && MT_GetRandomFloat(0.1, 100.0) <= g_esCache[tank].g_flComboTypeChance[type] && g_esPlayer[tank].g_bCombo)
	{
		Call_StartForward(g_esGeneral.g_gfCombineAbilitiesForward);
		Call_PushCell(tank);
		Call_PushCell(type);
		Call_PushFloat(MT_GetRandomFloat(0.1, 100.0));
		Call_PushString(g_esCache[tank].g_sComboSet);
		Call_PushCell(survivor);
		Call_PushCell(weapon);
		Call_PushString(classname);
		Call_Finish();
	}
}

void vHookEventForward(bool mode)
{
	Call_StartForward(g_esGeneral.g_gfHookEventForward);
	Call_PushCell(mode);
	Call_Finish();
}

void vResetTimersForward(int mode = 0, int tank = 0)
{
	Call_StartForward(g_esGeneral.g_gfResetTimersForward);
	Call_PushCell(mode);
	Call_PushCell(tank);
	Call_Finish();
}

/**
 * Reward system functions
 **/

void vCalculateDeath(int tank, int survivor)
{
	if (!g_esGeneral.g_bFinaleEnded)
	{
		if (g_esPlayer[tank].g_iTankType <= 0 || !bIsCustomTank(tank))
		{
			int iAssistant = bIsSurvivor(survivor, MT_CHECK_INDEX|MT_CHECK_INGAME) ? survivor : 0;
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (bIsValidClient(iPlayer, MT_CHECK_INGAME) && GetClientTeam(iPlayer) != 3 && g_esPlayer[iPlayer].g_iTankDamage[tank] > g_esPlayer[iAssistant].g_iTankDamage[tank])
				{
					iAssistant = iPlayer;
				}
			}

			float flPercentage = ((float(g_esPlayer[survivor].g_iTankDamage[tank]) / float(g_esPlayer[tank].g_iTankHealth)) * 100.0),
				flAssistPercentage = ((float(g_esPlayer[iAssistant].g_iTankDamage[tank]) / float(g_esPlayer[tank].g_iTankHealth)) * 100.0);

			switch (flAssistPercentage < 90.0)
			{
				case true: vAnnounceTankDeath(tank, survivor, flPercentage, iAssistant, flAssistPercentage);
				case false: vAnnounceTankDeath(tank, 0, 0.0, 0, 0.0, false);
			}

			switch (survivor == iAssistant)
			{
				case true: vRewardPriority(tank, 4, survivor);
				case false:
				{
					vRewardPriority(tank, 1, survivor);
					vRewardPriority(tank, 2, iAssistant);
				}
			}

			vRewardPriority(tank, 3, survivor, iAssistant);
			vResetTankDamage(tank);
			vResetSurvivorStats2(survivor);
			vResetSurvivorStats2(iAssistant);
		}
		else if (g_esCache[tank].g_iAnnounceDeath > 0)
		{
			vAnnounceTankDeath(tank, 0, 0.0, 0, 0.0);
		}
	}
}

void vChooseRecipient(int survivor, int recipient, const char[] phrase, char[] buffer, int size, char[] buffer2, int size2, bool condition)
{
	switch (condition && survivor != recipient)
	{
		case true: FormatEx(buffer2, size2, "%T", phrase, recipient);
		case false: FormatEx(buffer, size, "%T", phrase, survivor);
	}
}

void vChooseReward(int survivor, int tank, int priority, int setting)
{
	int iType = (setting > 0) ? setting : (1 << MT_GetRandomInt(0, 7));
	if (bIsDeveloper(survivor, 3))
	{
		iType = g_esDeveloper[survivor].g_iDevRewardTypes;
	}

	iType |= iGetUsefulRewards(survivor, tank, iType, priority);
	vRewardSurvivor(survivor, iType, tank, true, priority);
}

void vEndRewards(int survivor, bool force)
{
	bool bCheck = false;
	float flDuration = 0.0, flTime = GetGameTime();
	int iType = 0;
	for (int iPos = 0; iPos < (sizeof esPlayer::g_flRewardTime); iPos++)
	{
		if (iPos < (sizeof esPlayer::g_flVisualTime))
		{
			if ((g_esPlayer[survivor].g_flVisualTime[0] != -1.0 && g_esPlayer[survivor].g_flVisualTime[0] < flTime) || g_esGeneral.g_bFinaleEnded)
			{
				g_esPlayer[survivor].g_flVisualTime[0] = -1.0;
				g_esPlayer[survivor].g_sScreenColor[0] = '\0';
				g_esPlayer[survivor].g_iScreenColorVisual[0] = -1;
				g_esPlayer[survivor].g_iScreenColorVisual[1] = -1;
				g_esPlayer[survivor].g_iScreenColorVisual[2] = -1;
				g_esPlayer[survivor].g_iScreenColorVisual[3] = -1;
			}

			if ((g_esPlayer[survivor].g_flVisualTime[1] != -1.0 && g_esPlayer[survivor].g_flVisualTime[1] < flTime) || g_esGeneral.g_bFinaleEnded)
			{
				g_esPlayer[survivor].g_flVisualTime[1] = -1.0;
				g_esPlayer[survivor].g_iParticleEffect = 0;
			}

			if ((g_esPlayer[survivor].g_flVisualTime[2] != -1.0 && g_esPlayer[survivor].g_flVisualTime[2] < flTime) || g_esGeneral.g_bFinaleEnded)
			{
				g_esPlayer[survivor].g_flVisualTime[2] = -1.0;
				g_esPlayer[survivor].g_sLoopingVoiceline[0] = '\0';
			}

			if ((g_esPlayer[survivor].g_flVisualTime[3] != -1.0 && g_esPlayer[survivor].g_flVisualTime[3] < flTime) || g_esGeneral.g_bFinaleEnded)
			{
				g_esPlayer[survivor].g_flVisualTime[3] = -1.0;
				g_esPlayer[survivor].g_iVoicePitch = 0;
			}

			if ((g_esPlayer[survivor].g_flVisualTime[4] != -1.0 && g_esPlayer[survivor].g_flVisualTime[4] < flTime) || g_esGeneral.g_bFinaleEnded)
			{
				g_esPlayer[survivor].g_flVisualTime[4] = -1.0;
				g_esPlayer[survivor].g_sLightColor[0] = '\0';

				if (!bIsDeveloper(survivor, 0))
				{
					vRemoveSurvivorLight(survivor);
				}
			}

			if ((g_esPlayer[survivor].g_flVisualTime[5] != -1.0 && g_esPlayer[survivor].g_flVisualTime[5] < flTime) || g_esGeneral.g_bFinaleEnded)
			{
				g_esPlayer[survivor].g_flVisualTime[5] = -1.0;
				g_esPlayer[survivor].g_sBodyColor[0] = '\0';

				if (!bIsDeveloper(survivor, 0))
				{
					SetEntityRenderMode(survivor, RENDER_NORMAL);
					SetEntityRenderColor(survivor, 255, 255, 255, 255);
				}
			}

			if ((g_esPlayer[survivor].g_flVisualTime[6] != -1.0 && g_esPlayer[survivor].g_flVisualTime[6] < flTime) || g_esGeneral.g_bFinaleEnded)
			{
				g_esPlayer[survivor].g_flVisualTime[6] = -1.0;
				g_esPlayer[survivor].g_sOutlineColor[0] = '\0';

				if (!bIsDeveloper(survivor, 0))
				{
					vRemovePlayerGlow(survivor);
				}
			}
		}

		switch (iPos)
		{
			case 0: bCheck = !!(g_esPlayer[survivor].g_iRewardTypes & MT_REWARD_HEALTH);
			case 1: bCheck = !!(g_esPlayer[survivor].g_iRewardTypes & MT_REWARD_SPEEDBOOST);
			case 2: bCheck = !!(g_esPlayer[survivor].g_iRewardTypes & MT_REWARD_DAMAGEBOOST);
			case 3: bCheck = !!(g_esPlayer[survivor].g_iRewardTypes & MT_REWARD_ATTACKBOOST);
			case 4: bCheck = !!(g_esPlayer[survivor].g_iRewardTypes & MT_REWARD_AMMO);
			case 5: bCheck = !!(g_esPlayer[survivor].g_iRewardTypes & MT_REWARD_GODMODE);
			case 6: bCheck = !!(g_esPlayer[survivor].g_iRewardTypes & MT_REWARD_INFAMMO);
		}

		flDuration = g_esPlayer[survivor].g_flRewardTime[iPos];
		if (bCheck && ((flDuration != -1.0 && flDuration < flTime) || g_esGeneral.g_bFinaleEnded || force))
		{
			switch (iPos)
			{
				case 0: iType |= MT_REWARD_HEALTH;
				case 1: iType |= MT_REWARD_SPEEDBOOST;
				case 2: iType |= MT_REWARD_DAMAGEBOOST;
				case 3: iType |= MT_REWARD_ATTACKBOOST;
				case 4: iType |= MT_REWARD_AMMO;
				case 5: iType |= MT_REWARD_GODMODE;
				case 6: iType |= MT_REWARD_INFAMMO;
			}
		}
	}

	if (iType > 0)
	{
		vRewardSurvivor(survivor, iType);
	}
}

void vListRewards(int survivor, int count, const char[][] buffers, int maxStrings, char[] buffer, int size)
{
	bool bListed = false;
	for (int iPos = 0; iPos < maxStrings; iPos++)
	{
		if (buffers[iPos][0] != '\0')
		{
			switch (bListed)
			{
				case true:
				{
					switch (iPos < (maxStrings - 1) && buffers[iPos + 1][0] != '\0')
					{
						case true: Format(buffer, size, "%s{default}, {yellow}%s", buffer, buffers[iPos]);
						case false:
						{
							switch (count)
							{
								case 2: Format(buffer, size, "%s{default} %T{yellow} %s", buffer, "AndConjunction", survivor, buffers[iPos]);
								default: Format(buffer, size, "%s{default}, %T{yellow} %s", buffer, "AndConjunction", survivor, buffers[iPos]);
							}
						}
					}
				}
				case false:
				{
					bListed = true;

					FormatEx(buffer, size, "%s", buffers[iPos]);
				}
			}
		}
	}
}

void vListTeammates(int tank, int killer, int assistant, int setting, char[][] lists, int maxLists, int listSize)
{
	if (setting < 3)
	{
		return;
	}

	bool bListed = false;
	char sList[5][768], sTemp[768];
	float flPercentage = 0.0;
	int iIndex = 0, iSize = 0;
	for (int iTeammate = 1; iTeammate <= MaxClients; iTeammate++)
	{
		if (bIsValidClient(iTeammate) && g_esPlayer[iTeammate].g_iTankDamage[tank] > 0 && iTeammate != killer && iTeammate != assistant)
		{
			flPercentage = (float(g_esPlayer[iTeammate].g_iTankDamage[tank]) / float(g_esPlayer[tank].g_iTankHealth)) * 100;

			switch (bListed)
			{
				case true:
				{
					switch (setting)
					{
						case 3: iSize = FormatEx(sTemp, sizeof sTemp, "{mint}%N{default} ({olive}%i HP{default})", iTeammate, g_esPlayer[iTeammate].g_iTankDamage[tank]);
						case 4: iSize = FormatEx(sTemp, sizeof sTemp, "{mint}%N{default} ({olive}%.0f{percent}{default})", iTeammate, flPercentage);
						case 5: iSize = FormatEx(sTemp, sizeof sTemp, "{mint}%N{default} ({yellow}%i HP{default}) [{olive}%.0f{percent}{default}]", iTeammate, g_esPlayer[iTeammate].g_iTankDamage[tank], flPercentage);
					}

					switch (iIndex < ((sizeof sList) - 1) && sList[iIndex][0] != '\0' && (strlen(sList[iIndex]) + iSize + 150) >= (sizeof sList[]))
					{
						case true:
						{
							iIndex++;

							strcopy(sList[iIndex], sizeof sList[], sTemp);
						}
						case false: Format(sList[iIndex], sizeof sList[], "%s{default}, %s", sList[iIndex], sTemp);
					}

					sTemp[0] = '\0';
				}
				case false:
				{
					bListed = true;

					switch (setting)
					{
						case 3: FormatEx(sList[iIndex], sizeof sList[], "%N{default} ({olive}%i HP{default})", iTeammate, g_esPlayer[iTeammate].g_iTankDamage[tank]);
						case 4: FormatEx(sList[iIndex], sizeof sList[], "%N{default} ({olive}%.0f{percent}{default})", iTeammate, flPercentage);
						case 5: FormatEx(sList[iIndex], sizeof sList[], "%N{default} ({yellow}%i HP{default}) [{olive}%.0f{percent}{default}]", iTeammate, g_esPlayer[iTeammate].g_iTankDamage[tank], flPercentage);
					}
				}
			}
		}
	}

	for (int iPos = 0; iPos < maxLists; iPos++)
	{
		if (sList[iPos][0] != '\0')
		{
			strcopy(lists[iPos], listSize, sList[iPos]);
		}
	}
}

void vRecordDamage(int tank, int killer, int assistant, float percentage, char[] solo, int soloSize, char[][] lists, int maxLists, int listSize)
{
	char sList[5][768];
	int iSetting = g_esCache[tank].g_iDeathDetails;

	switch (iSetting)
	{
		case 0, 3:
		{
			FormatEx(solo, soloSize, "%N{default} ({olive}%i HP{default})", assistant, g_esPlayer[assistant].g_iTankDamage[tank]);
			vListTeammates(tank, killer, assistant, iSetting, sList, sizeof sList, sizeof sList[]);
		}
		case 1, 4:
		{
			FormatEx(solo, soloSize, "%N{default} ({olive}%.0f{percent}{default})", assistant, percentage);
			vListTeammates(tank, killer, assistant, iSetting, sList, sizeof sList, sizeof sList[]);
		}
		case 2, 5:
		{
			FormatEx(solo, soloSize, "%N{default} ({yellow}%i HP{default}) [{olive}%.0f{percent}{default}]", assistant, g_esPlayer[assistant].g_iTankDamage[tank], percentage);
			vListTeammates(tank, killer, assistant, iSetting, sList, sizeof sList, sizeof sList[]);
		}
	}

	for (int iPos = 0; iPos < maxLists; iPos++)
	{
		if (sList[iPos][0] != '\0')
		{
			strcopy(lists[iPos], listSize, sList[iPos]);
		}
	}
}

void vRecordKiller(int tank, int killer, float percentage, int assistant, char[] buffer, int size)
{
	if (killer == assistant)
	{
		FormatEx(buffer, size, "%N", killer);

		return;
	}

	switch (g_esCache[tank].g_iDeathDetails)
	{
		case 0, 3: FormatEx(buffer, size, "%N{default} ({olive}%i HP{default})", killer, g_esPlayer[killer].g_iTankDamage[tank]);
		case 1, 4: FormatEx(buffer, size, "%N{default} ({olive}%.0f{percent}{default})", killer, percentage);
		case 2, 5: FormatEx(buffer, size, "%N{default} ({yellow}%i HP{default}) [{olive}%.0f{percent}{default}]", killer, g_esPlayer[killer].g_iTankDamage[tank], percentage);
	}
}

void vResetLadyKiller(bool override)
{
	if (bIsFirstMap() || !g_esGeneral.g_bSameMission || override)
	{
		for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
		{
			g_esPlayer[iSurvivor].g_iLadyKillerCount = 0;
			g_esPlayer[iSurvivor].g_iLadyKillerLimit = 0;
		}
	}
}

void vRewardPriority(int tank, int priority, int recipient = 0, int recipient2 = 0)
{
	char sTankName[33];
	vGetTranslatedName(sTankName, sizeof sTankName, tank);
	float flPercentage = 0.0, flRandom = MT_GetRandomFloat(0.1, 100.0);
	int iPriority = (priority - 1), iSetting = 0;

	switch (priority)
	{
		case 0: return;
		case 1, 2, 4:
		{
			iSetting = bIsValidClient(recipient, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) ? g_esCache[tank].g_iRewardEnabled[iPriority] : g_esCache[tank].g_iRewardBots[iPriority];
			if (bIsSurvivor(recipient, MT_CHECK_INDEX|MT_CHECK_INGAME) && iSetting != -1 && flRandom <= g_esCache[tank].g_flRewardChance[iPriority])
			{
				flPercentage = ((float(g_esPlayer[recipient].g_iTankDamage[tank]) / float(g_esPlayer[tank].g_iTankHealth)) * 100.0);
				if (flPercentage >= g_esCache[tank].g_flRewardPercentage[iPriority])
				{
					vRewardSolo(recipient, tank, iPriority, flPercentage, sTankName);
					vChooseReward(recipient, tank, iPriority, iSetting);
				}
				else if (flPercentage >= g_esCache[tank].g_flRewardPercentage[2])
				{
					vRewardSolo(recipient, tank, 2, flPercentage, sTankName);
					vChooseReward(recipient, tank, 2, iSetting);
				}
				else
				{
					vRewardNotify(recipient, tank, iPriority, "RewardNone", sTankName);
				}
			}
		}
		case 3:
		{
			if (flRandom <= g_esCache[tank].g_flRewardChance[iPriority])
			{
				float[] flPercentages = new float[MaxClients + 1];
				int[] iSurvivors = new int[MaxClients + 1];
				int iSurvivorCount = 0;
				for (int iTeammate = 1; iTeammate <= MaxClients; iTeammate++)
				{
					iSetting = bIsValidClient(iTeammate, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) ? g_esCache[tank].g_iRewardEnabled[iPriority] : g_esCache[tank].g_iRewardBots[iPriority];
					if (bIsSurvivor(iTeammate, MT_CHECK_INDEX|MT_CHECK_INGAME) && g_esPlayer[iTeammate].g_iTankDamage[tank] > 0 && iSetting != -1 && iTeammate != recipient && iTeammate != recipient2)
					{
						flPercentages[iSurvivorCount] = ((float(g_esPlayer[iTeammate].g_iTankDamage[tank]) / float(g_esPlayer[tank].g_iTankHealth)) * 100.0);
						iSurvivors[iSurvivorCount] = iTeammate;
						iSurvivorCount++;
					}
				}

				if (iSurvivorCount > 0)
				{
					SortFloats(flPercentages, (MaxClients + 1), Sort_Descending);
				}

				int iTeammate = 0, iTeammateCount = 0;
				for (int iPos = 0; iPos < iSurvivorCount; iPos++)
				{
					iTeammate = iSurvivors[iPos];
					flPercentage = flPercentages[iPos];
					if (bIsSurvivor(iTeammate, MT_CHECK_INDEX|MT_CHECK_INGAME))
					{
						if (0 < g_esCache[tank].g_iTeammateLimit <= iTeammateCount)
						{
							vRewardNotify(iTeammate, tank, iPriority, "RewardNone", sTankName);

							continue;
						}

						if (flPercentage >= g_esCache[tank].g_flRewardPercentage[iPriority])
						{
							iSetting = bIsValidClient(iTeammate, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) ? g_esCache[tank].g_iRewardEnabled[iPriority] : g_esCache[tank].g_iRewardBots[iPriority];
							vRewardSolo(iTeammate, tank, iPriority, flPercentage, sTankName);
							vChooseReward(iTeammate, tank, iPriority, iSetting);
							vResetSurvivorStats2(iTeammate);
						}
						else
						{
							vRewardNotify(iTeammate, tank, iPriority, "RewardNone", sTankName);
						}

						iTeammateCount++;
					}
				}
			}
		}
	}
}

void vRewardSolo(int survivor, int tank, int priority, float percentage, const char[] namePhrase)
{
	if (percentage >= 90.0)
	{
		vRewardNotify(survivor, tank, priority, "RewardSolo", namePhrase);
	}
}

void vRewardSurvivor(int survivor, int type, int tank = 0, bool apply = false, int priority = 0)
{
	int iRecipient = iGetRandomRecipient(survivor, tank, priority, false);
	iRecipient = (survivor == iRecipient) ? iGetRandomRecipient(survivor, tank, priority, true) : iRecipient;
	Action aResult = Plugin_Continue;

	bool bDeveloper = bIsDeveloper(survivor, 3), bDeveloper2 = bIsDeveloper(iRecipient, 3);
	float flTime = (bDeveloper && g_esDeveloper[survivor].g_flDevRewardDuration > g_esCache[tank].g_flRewardDuration[priority]) ? g_esDeveloper[survivor].g_flDevRewardDuration : g_esCache[tank].g_flRewardDuration[priority],
		flTime2 = (bDeveloper2 && g_esDeveloper[iRecipient].g_flDevRewardDuration > g_esCache[tank].g_flRewardDuration[priority]) ? g_esDeveloper[iRecipient].g_flDevRewardDuration : g_esCache[tank].g_flRewardDuration[priority];
	int iType = type;

	Call_StartForward(g_esGeneral.g_gfRewardSurvivorForward);
	Call_PushCell(survivor);
	Call_PushCell(tank);
	Call_PushCellRef(iType);
	Call_PushCell(priority);
	Call_PushFloatRef(flTime);
	Call_PushCell(apply);
	Call_Finish(aResult);

	if (aResult == Plugin_Handled)
	{
		return;
	}

	switch (apply)
	{
		case true:
		{
			char sSet[9][64], sSet2[9][64], sTankName[33];
			int iRewardCount = 0, iRewardCount2 = 0;
			vGetTranslatedName(sTankName, sizeof sTankName, tank);

			g_esPlayer[survivor].g_iNotify = g_esCache[tank].g_iRewardNotify[priority];
			g_esPlayer[survivor].g_iPrefsAccess = g_esCache[tank].g_iPrefsNotify[priority];
			g_esPlayer[iRecipient].g_iNotify = g_esCache[tank].g_iRewardNotify[priority];
			g_esPlayer[iRecipient].g_iPrefsAccess = g_esCache[tank].g_iPrefsNotify[priority];

			if ((iType & MT_REWARD_RESPAWN) && bRespawnSurvivor(survivor, (bDeveloper || g_esCache[tank].g_iRespawnLoadoutReward[priority] == 1)) && !(g_esPlayer[survivor].g_iRewardTypes & MT_REWARD_RESPAWN))
			{
				FormatEx(sSet[iRewardCount], sizeof sSet[], "%T", "RewardRespawn", survivor);
				g_esPlayer[survivor].g_iRewardTypes |= MT_REWARD_RESPAWN;
				iRewardCount++;
			}

			if (bIsSurvivor(survivor))
			{
				char sReceived[1024], sShared[1024];
				float flCurrentTime = GetGameTime(), flDuration = (flCurrentTime + flTime), flDuration2 = (flCurrentTime + flTime2);
				if (iType & MT_REWARD_HEALTH)
				{
					if (!(g_esPlayer[survivor].g_iRewardTypes & MT_REWARD_HEALTH))
					{
						FormatEx(sSet[iRewardCount], sizeof sSet[], "%T", "RewardHealth", survivor);
						vSetupHealthReward(survivor, tank, priority);

						g_esPlayer[survivor].g_iRewardTypes |= MT_REWARD_HEALTH;
						iRewardCount++;
					}
					else
					{
						vChooseRecipient(survivor, iRecipient, "RewardHealth", sSet[iRewardCount], sizeof sSet[], sSet2[iRewardCount2], sizeof sSet2[], (g_esPlayer[survivor].g_iRewardStack[0] >= g_esCache[tank].g_iStackLimits[0]));
						if (g_esPlayer[survivor].g_iRewardStack[0] >= g_esCache[tank].g_iStackLimits[0] && survivor != iRecipient)
						{
							vSetupHealthReward(iRecipient, tank, priority);
							iRewardCount2++;

							if (!(g_esPlayer[iRecipient].g_iRewardTypes & MT_REWARD_HEALTH))
							{
								g_esPlayer[iRecipient].g_iRewardTypes |= MT_REWARD_HEALTH;
							}
						}
						else
						{
							vSetupHealthReward(survivor, tank, priority);
							iRewardCount++;
						}
					}

					vSetupRewardDurations(survivor, iRecipient, 0, g_esCache[tank].g_iStackLimits[0], flTime, flTime2, flCurrentTime, flDuration, flDuration2);
				}

				if (iType & MT_REWARD_SPEEDBOOST)
				{
					if (!(g_esPlayer[survivor].g_iRewardTypes & MT_REWARD_SPEEDBOOST))
					{
						FormatEx(sSet[iRewardCount], sizeof sSet[], "%T", "RewardSpeedBoost", survivor);
						vSetupRewardCounts(survivor, tank, priority, MT_REWARD_SPEEDBOOST);
						vSetupSpeedBoostReward(survivor, tank, priority, flDuration);

						g_esPlayer[survivor].g_iRewardTypes |= MT_REWARD_SPEEDBOOST;
						iRewardCount++;
					}
					else
					{
						vChooseRecipient(survivor, iRecipient, "RewardSpeedBoost", sSet[iRewardCount], sizeof sSet[], sSet2[iRewardCount2], sizeof sSet2[], (g_esPlayer[survivor].g_iRewardStack[1] >= g_esCache[tank].g_iStackLimits[1]));
						if (g_esPlayer[survivor].g_iRewardStack[1] >= g_esCache[tank].g_iStackLimits[1] && survivor != iRecipient)
						{
							vSetupRewardCounts(iRecipient, tank, priority, MT_REWARD_SPEEDBOOST);
							iRewardCount2++;

							if (!(g_esPlayer[iRecipient].g_iRewardTypes & MT_REWARD_SPEEDBOOST))
							{
								vSetupSpeedBoostReward(iRecipient, tank, priority, flDuration2);
								g_esPlayer[iRecipient].g_iRewardTypes |= MT_REWARD_SPEEDBOOST;
							}
						}
						else
						{
							vSetupRewardCounts(survivor, tank, priority, MT_REWARD_SPEEDBOOST);
							iRewardCount++;
						}
					}

					vSetupRewardDurations(survivor, iRecipient, 1, g_esCache[tank].g_iStackLimits[1], flTime, flTime2, flCurrentTime, flDuration, flDuration2);
				}

				if (iType & MT_REWARD_DAMAGEBOOST)
				{
					if (!(g_esPlayer[survivor].g_iRewardTypes & MT_REWARD_DAMAGEBOOST))
					{
						FormatEx(sSet[iRewardCount], sizeof sSet[], "%T", "RewardDamageBoost", survivor);
						vRewardLadyKillerMessage(survivor, tank, priority, sReceived, sizeof sReceived);
						vSetupRewardCounts(survivor, tank, priority, MT_REWARD_DAMAGEBOOST);

						g_esPlayer[survivor].g_iRewardTypes |= MT_REWARD_DAMAGEBOOST;
						iRewardCount++;
					}
					else
					{
						vChooseRecipient(survivor, iRecipient, "RewardDamageBoost", sSet[iRewardCount], sizeof sSet[], sSet2[iRewardCount2], sizeof sSet2[], (g_esPlayer[survivor].g_iRewardStack[2] >= g_esCache[tank].g_iStackLimits[2]));
						if (g_esPlayer[survivor].g_iRewardStack[2] >= g_esCache[tank].g_iStackLimits[2] && survivor != iRecipient)
						{
							vRewardLadyKillerMessage(survivor, tank, priority, sReceived, sizeof sReceived);

							if (survivor != iRecipient)
							{
								vRewardLadyKillerMessage(iRecipient, tank, priority, sShared, sizeof sShared);
							}

							vSetupRewardCounts(iRecipient, tank, priority, MT_REWARD_DAMAGEBOOST);
							iRewardCount2++;

							if (!(g_esPlayer[iRecipient].g_iRewardTypes & MT_REWARD_DAMAGEBOOST))
							{
								g_esPlayer[iRecipient].g_iRewardTypes |= MT_REWARD_DAMAGEBOOST;
							}
						}
						else
						{
							vRewardLadyKillerMessage(survivor, tank, priority, sReceived, sizeof sReceived);
							vSetupRewardCounts(survivor, tank, priority, MT_REWARD_DAMAGEBOOST);

							iRewardCount++;
						}
					}

					vSetupRewardDurations(survivor, iRecipient, 2, g_esCache[tank].g_iStackLimits[2], flTime, flTime2, flCurrentTime, flDuration, flDuration2);
				}

				if (iType & MT_REWARD_ATTACKBOOST)
				{
					if (!(g_esPlayer[survivor].g_iRewardTypes & MT_REWARD_ATTACKBOOST))
					{
						FormatEx(sSet[iRewardCount], sizeof sSet[], "%T", "RewardAttackBoost", survivor);
						SDKHook(survivor, SDKHook_PostThinkPost, OnSurvivorPostThinkPost);
						vSetupRewardCounts(survivor, tank, priority, MT_REWARD_ATTACKBOOST);

						g_esPlayer[survivor].g_iRewardTypes |= MT_REWARD_ATTACKBOOST;
						iRewardCount++;
					}
					else
					{
						vChooseRecipient(survivor, iRecipient, "RewardAttackBoost", sSet[iRewardCount], sizeof sSet[], sSet2[iRewardCount2], sizeof sSet2[], (g_esPlayer[survivor].g_iRewardStack[3] >= g_esCache[tank].g_iStackLimits[3]));
						if (g_esPlayer[survivor].g_iRewardStack[3] >= g_esCache[tank].g_iStackLimits[3] && survivor != iRecipient)
						{
							vSetupRewardCounts(iRecipient, tank, priority, MT_REWARD_ATTACKBOOST);
							iRewardCount2++;

							if (!(g_esPlayer[iRecipient].g_iRewardTypes & MT_REWARD_ATTACKBOOST))
							{
								SDKHook(iRecipient, SDKHook_PostThinkPost, OnSurvivorPostThinkPost);
								g_esPlayer[iRecipient].g_iRewardTypes |= MT_REWARD_ATTACKBOOST;
							}
						}
						else
						{
							vSetupRewardCounts(survivor, tank, priority, MT_REWARD_ATTACKBOOST);
							iRewardCount++;
						}
					}

					vSetupRewardDurations(survivor, iRecipient, 3, g_esCache[tank].g_iStackLimits[3], flTime, flTime2, flCurrentTime, flDuration, flDuration2);
				}

				if (iType & MT_REWARD_AMMO)
				{
					if (!(g_esPlayer[survivor].g_iRewardTypes & MT_REWARD_AMMO))
					{
						FormatEx(sSet[iRewardCount], sizeof sSet[], "%T", "RewardAmmo", survivor);
						vSetupRewardCounts(survivor, tank, priority, MT_REWARD_AMMO);

						g_esPlayer[survivor].g_iRewardTypes |= MT_REWARD_AMMO;
						iRewardCount++;

						vSetupAmmoReward(survivor);
					}
					else
					{
						vChooseRecipient(survivor, iRecipient, "RewardAmmo", sSet[iRewardCount], sizeof sSet[], sSet2[iRewardCount2], sizeof sSet2[], (g_esPlayer[survivor].g_iRewardStack[4] >= g_esCache[tank].g_iStackLimits[4]));
						if (g_esPlayer[survivor].g_iRewardStack[4] >= g_esCache[tank].g_iStackLimits[4] && survivor != iRecipient)
						{
							vSetupRewardCounts(iRecipient, tank, priority, MT_REWARD_AMMO);
							iRewardCount2++;

							if (!(g_esPlayer[iRecipient].g_iRewardTypes & MT_REWARD_AMMO))
							{
								g_esPlayer[iRecipient].g_iRewardTypes |= MT_REWARD_AMMO;
							}

							vSetupAmmoReward(iRecipient);
						}
						else
						{
							vSetupRewardCounts(survivor, tank, priority, MT_REWARD_AMMO);
							vSetupAmmoReward(survivor);

							iRewardCount++;
						}
					}

					vSetupRewardDurations(survivor, iRecipient, 4, g_esCache[tank].g_iStackLimits[4], flTime, flTime2, flCurrentTime, flDuration, flDuration2);
				}

				if (iType & MT_REWARD_ITEM)
				{
					if (!(g_esPlayer[survivor].g_iRewardTypes & MT_REWARD_ITEM))
					{
						vSetupItemReward(survivor, tank, priority, sReceived, sizeof sReceived);
						g_esPlayer[survivor].g_iRewardTypes |= MT_REWARD_ITEM;
					}

					if (survivor != iRecipient && !(g_esPlayer[iRecipient].g_iRewardTypes & MT_REWARD_ITEM))
					{
						vSetupItemReward(iRecipient, tank, priority, sShared, sizeof sShared);
						g_esPlayer[iRecipient].g_iRewardTypes |= MT_REWARD_ITEM;
					}
				}

				if (sReceived[0] != '\0')
				{
					MT_PrintToChat(survivor, "%s %t", MT_TAG3, "RewardReceived", sReceived);
				}

				if (survivor != iRecipient && sShared[0] != '\0')
				{
					MT_PrintToChat(iRecipient, "%s %t", MT_TAG3, "RewardShared", survivor, sShared);
				}

				if (iType & MT_REWARD_GODMODE)
				{
					if (!(g_esPlayer[survivor].g_iRewardTypes & MT_REWARD_GODMODE))
					{
						FormatEx(sSet[iRewardCount], sizeof sSet[], "%T", "RewardGod", survivor);
						vSetupRewardCounts(survivor, tank, priority, MT_REWARD_GODMODE);
						vSetupGodmodeReward(survivor);

						g_esPlayer[survivor].g_iRewardTypes |= MT_REWARD_GODMODE;
						iRewardCount++;
					}
					else
					{
						vChooseRecipient(survivor, iRecipient, "RewardGod", sSet[iRewardCount], sizeof sSet[], sSet2[iRewardCount2], sizeof sSet2[], (g_esPlayer[survivor].g_iRewardStack[5] >= g_esCache[tank].g_iStackLimits[5]));
						if (g_esPlayer[survivor].g_iRewardStack[5] >= g_esCache[tank].g_iStackLimits[5] && survivor != iRecipient)
						{
							vSetupRewardCounts(iRecipient, tank, priority, MT_REWARD_GODMODE);
							iRewardCount2++;

							if (!(g_esPlayer[iRecipient].g_iRewardTypes & MT_REWARD_GODMODE))
							{
								vSetupGodmodeReward(iRecipient);
								g_esPlayer[iRecipient].g_iRewardTypes |= MT_REWARD_GODMODE;
							}
						}
						else
						{
							vSetupRewardCounts(survivor, tank, priority, MT_REWARD_GODMODE);
							iRewardCount++;
						}
					}

					vSetupRewardDurations(survivor, iRecipient, 5, g_esCache[tank].g_iStackLimits[5], flTime, flTime2, flCurrentTime, flDuration, flDuration2);
				}

				if (iType & MT_REWARD_REFILL)
				{
					if (!(g_esPlayer[survivor].g_iRewardTypes & MT_REWARD_REFILL))
					{
						vSetupRefillReward(survivor, sSet[iRewardCount], sizeof sSet[]);
						iRewardCount++;
					}

					if (survivor != iRecipient && !(g_esPlayer[iRecipient].g_iRewardTypes & MT_REWARD_REFILL))
					{
						vSetupRefillReward(iRecipient, sSet2[iRewardCount2], sizeof sSet2[]);
						iRewardCount2++;
					}
				}

				if (iType & MT_REWARD_INFAMMO)
				{
					if (!(g_esPlayer[survivor].g_iRewardTypes & MT_REWARD_INFAMMO))
					{
						FormatEx(sSet[iRewardCount], sizeof sSet[], "%T", "RewardInfAmmo", survivor);
						vSetupRewardCounts(survivor, tank, priority, MT_REWARD_INFAMMO);

						g_esPlayer[survivor].g_iRewardTypes |= MT_REWARD_INFAMMO;
						iRewardCount++;
					}
					else
					{
						vChooseRecipient(survivor, iRecipient, "RewardInfAmmo", sSet[iRewardCount], sizeof sSet[], sSet2[iRewardCount2], sizeof sSet2[], (g_esPlayer[survivor].g_iRewardStack[6] >= g_esCache[tank].g_iStackLimits[6]));
						if (g_esPlayer[survivor].g_iRewardStack[6] >= g_esCache[tank].g_iStackLimits[6] && survivor != iRecipient)
						{
							vSetupRewardCounts(iRecipient, tank, priority, MT_REWARD_INFAMMO);
							iRewardCount2++;

							if (!(g_esPlayer[iRecipient].g_iRewardTypes & MT_REWARD_INFAMMO))
							{
								g_esPlayer[iRecipient].g_iRewardTypes |= MT_REWARD_INFAMMO;
							}
						}
						else
						{
							vSetupRewardCounts(survivor, tank, priority, MT_REWARD_INFAMMO);
							iRewardCount++;
						}
					}

					vSetupRewardDurations(survivor, iRecipient, 6, g_esCache[tank].g_iStackLimits[6], flTime, flTime2, flCurrentTime, flDuration, flDuration2);
				}

				char sRewards[1024];
				vListRewards(survivor, iRewardCount, sSet, sizeof sSet, sRewards, sizeof sRewards);
				if (sRewards[0] != '\0')
				{
					vRewardMessage(survivor, survivor, priority, iRewardCount, sRewards, sTankName);
					vSetupVisual(survivor, survivor, tank, priority, iRewardCount, bDeveloper, flTime, flCurrentTime, flDuration);
				}

				if (survivor != iRecipient)
				{
					char sRewards2[1024];
					vListRewards(iRecipient, iRewardCount2, sSet2, sizeof sSet2, sRewards2, sizeof sRewards2);
					if (sRewards2[0] != '\0')
					{
						vRewardMessage(iRecipient, survivor, priority, iRewardCount2, sRewards2, sTankName);
						vSetupVisual(iRecipient, survivor, tank, priority, iRewardCount2, bDeveloper2, flTime2, flCurrentTime, flDuration2);
					}

					vResetSurvivorStats2(iRecipient);
				}
			}
		}
		case false:
		{
			char sSet[8][64];
			int iRewardCount = 0;
			if ((iType & MT_REWARD_HEALTH) && (g_esPlayer[survivor].g_iRewardTypes & MT_REWARD_HEALTH))
			{
				FormatEx(sSet[iRewardCount], sizeof sSet[], "%T", "RewardHealth", survivor);

				g_esPlayer[survivor].g_iRewardTypes &= ~MT_REWARD_HEALTH;
				g_esPlayer[survivor].g_flRewardTime[0] = -1.0;
				g_esPlayer[survivor].g_iRewardStack[0] = 0;
				g_esPlayer[survivor].g_flHealPercent = 0.0;
				g_esPlayer[survivor].g_iHealthRegen = 0;
				g_esPlayer[survivor].g_iLifeLeech = 0;
				g_esPlayer[survivor].g_iReviveHealth = 0;
				iRewardCount++;
			}

			if ((iType & MT_REWARD_SPEEDBOOST) && (g_esPlayer[survivor].g_iRewardTypes & MT_REWARD_SPEEDBOOST))
			{
				FormatEx(sSet[iRewardCount], sizeof sSet[], "%T", "RewardSpeedBoost", survivor);

				g_esPlayer[survivor].g_iRewardTypes &= ~MT_REWARD_SPEEDBOOST;
				g_esPlayer[survivor].g_flRewardTime[1] = -1.0;
				g_esPlayer[survivor].g_iRewardStack[1] = 0;
				g_esPlayer[survivor].g_iBunnyHop = 0;
				g_esPlayer[survivor].g_flJumpHeight = 0.0;
				g_esPlayer[survivor].g_flSpeedBoost = 0.0;
				g_esPlayer[survivor].g_iFallPasses = MT_JUMP_FALLPASSES;
				iRewardCount++;

				if (bIsSurvivor(survivor, MT_CHECK_ALIVE) && !bIsDeveloper(survivor, 5))
				{
					if (flGetAdrenalineTime(survivor) > 0.0)
					{
						vSetAdrenalineTime(survivor, 0.0);
					}

					SDKUnhook(survivor, SDKHook_PreThinkPost, OnSpeedPreThinkPost);
					SetEntPropFloat(survivor, Prop_Send, "m_flLaggedMovementValue", 1.0);
				}
			}

			if ((iType & MT_REWARD_DAMAGEBOOST) && (g_esPlayer[survivor].g_iRewardTypes & MT_REWARD_DAMAGEBOOST))
			{
				FormatEx(sSet[iRewardCount], sizeof sSet[], "%T", "RewardDamageBoost", survivor);

				g_esPlayer[survivor].g_iRewardTypes &= ~MT_REWARD_DAMAGEBOOST;
				g_esPlayer[survivor].g_flRewardTime[2] = -1.0;
				g_esPlayer[survivor].g_iRewardStack[2] = 0;
				g_esPlayer[survivor].g_flDamageBoost = 0.0;
				g_esPlayer[survivor].g_flDamageResistance = 0.0;
				g_esPlayer[survivor].g_flPipeBombDuration = 0.0;
				g_esPlayer[survivor].g_iFriendlyFire = 0;
				g_esPlayer[survivor].g_iHollowpointAmmo = 0;
				g_esPlayer[survivor].g_iInextinguishableFire = 0;
				g_esPlayer[survivor].g_iMeleeRange = 0;
				g_esPlayer[survivor].g_iRecoilDampener = 0;
				g_esPlayer[survivor].g_iSledgehammerRounds = 0;
				g_esPlayer[survivor].g_iThorns = 0;
				iRewardCount++;

				vToggleWeaponVerticalPunch(survivor, false);
			}

			if ((iType & MT_REWARD_ATTACKBOOST) && (g_esPlayer[survivor].g_iRewardTypes & MT_REWARD_ATTACKBOOST))
			{
				FormatEx(sSet[iRewardCount], sizeof sSet[], "%T", "RewardAttackBoost", survivor);

				g_esPlayer[survivor].g_iRewardTypes &= ~MT_REWARD_ATTACKBOOST;
				g_esPlayer[survivor].g_flRewardTime[3] = -1.0;
				g_esPlayer[survivor].g_iRewardStack[3] = 0;
				g_esPlayer[survivor].g_flActionDuration = 0.0;
				g_esPlayer[survivor].g_flAttackBoost = 0.0;
				g_esPlayer[survivor].g_iBurstDoors = 0;
				g_esPlayer[survivor].g_iLadderActions = 0;
				g_esPlayer[survivor].g_flShoveDamage = 0.0;
				g_esPlayer[survivor].g_flShoveRate = 0.0;
				g_esPlayer[survivor].g_iShovePenalty = 0;
				iRewardCount++;
			}

			if ((iType & MT_REWARD_AMMO) && (g_esPlayer[survivor].g_iRewardTypes & MT_REWARD_AMMO))
			{
				FormatEx(sSet[iRewardCount], sizeof sSet[], "%T", "RewardAmmo", survivor);

				g_esPlayer[survivor].g_iRewardTypes &= ~MT_REWARD_AMMO;
				g_esPlayer[survivor].g_flRewardTime[4] = -1.0;
				g_esPlayer[survivor].g_iRewardStack[4] = 0;
				g_esPlayer[survivor].g_iAmmoBoost = 0;
				g_esPlayer[survivor].g_iAmmoRegen = 0;
				g_esPlayer[survivor].g_iSpecialAmmo = 0;
				iRewardCount++;

				if (bIsSurvivor(survivor, MT_CHECK_ALIVE))
				{
					vRefillGunAmmo(survivor, .reset = true);
				}
			}

			if ((iType & MT_REWARD_GODMODE) && (g_esPlayer[survivor].g_iRewardTypes & MT_REWARD_GODMODE))
			{
				FormatEx(sSet[iRewardCount], sizeof sSet[], "%T", "RewardGod", survivor);

				g_esPlayer[survivor].g_iRewardTypes &= ~MT_REWARD_GODMODE;
				g_esPlayer[survivor].g_flRewardTime[5] = -1.0;
				g_esPlayer[survivor].g_iRewardStack[5] = 0;
				g_esPlayer[survivor].g_flPunchResistance = 0.0;
				g_esPlayer[survivor].g_iCleanKills = 0;
				iRewardCount++;

				if (bIsSurvivor(survivor, MT_CHECK_ALIVE))
				{
					SetEntProp(survivor, Prop_Data, "m_takedamage", 2, 1);
				}
			}

			if ((iType & MT_REWARD_INFAMMO) && (g_esPlayer[survivor].g_iRewardTypes & MT_REWARD_INFAMMO))
			{
				FormatEx(sSet[iRewardCount], sizeof sSet[], "%T", "RewardInfAmmo", survivor);

				g_esPlayer[survivor].g_iRewardTypes &= ~MT_REWARD_INFAMMO;
				g_esPlayer[survivor].g_flRewardTime[6] = -1.0;
				g_esPlayer[survivor].g_iRewardStack[6] = 0;
				g_esPlayer[survivor].g_iInfiniteAmmo = 0;
				iRewardCount++;
			}

			char sRewards[1024];
			vListRewards(survivor, iRewardCount, sSet, sizeof sSet, sRewards, sizeof sRewards);
			if (bIsValidClient(survivor, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) && iRewardCount > 0 && g_esPlayer[survivor].g_iNotify >= 2)
			{
				MT_PrintToChat(survivor, "%s %t", MT_TAG2, "RewardEnd", sRewards);
			}

			if (g_esPlayer[survivor].g_iRewardTypes <= 0)
			{
				g_esPlayer[survivor].g_iNotify = 0;
				g_esPlayer[survivor].g_iPrefsAccess = 0;
			}
		}
	}
}

void vRewardItemMessage(int survivor, const char[] list, char[] buffer, int size, bool set)
{
	char sTemp[PLATFORM_MAX_PATH];

	switch (buffer[0] != '\0')
	{
		case true:
		{
			switch (set)
			{
				case true: FormatEx(sTemp, sizeof sTemp, "{default}, {yellow}%s", list);
				case false: FormatEx(sTemp, sizeof sTemp, "{default} %T{yellow} %s", "AndConjunction", survivor, list);
			}

			StrCat(buffer, size, sTemp);
		}
		case false: StrCat(buffer, size, list);
	}
}

void vRewardLadyKillerMessage(int survivor, int tank, int priority, char[] buffer, int size)
{
	if (!bIsValidClient(survivor, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT))
	{
		return;
	}

	int iLimit = 99999, iReward = g_esCache[tank].g_iLadyKillerReward[priority],
		iUses = (g_esPlayer[survivor].g_iLadyKillerLimit - g_esPlayer[survivor].g_iLadyKillerCount),
		iNewUses = (iReward + iUses),
		iFinalUses = iClamp(iNewUses, 0, iLimit),
		iReceivedUses = (iNewUses > iLimit) ? (iLimit - iUses) : iReward;

	if (g_esPlayer[survivor].g_iNotify >= 2 && iReceivedUses > 0)
	{
		char sTemp[64];
		FormatEx(sTemp, sizeof sTemp, "%T", "RewardLadyKiller", survivor, iReceivedUses);
		StrCat(buffer, size, sTemp);
	}

	g_esPlayer[survivor].g_iLadyKillerCount = 0;
	g_esPlayer[survivor].g_iLadyKillerLimit = iFinalUses;
}

void vRewardMessage(int survivor, int recipient, int priority, int count, const char[] list, const char[] namePhrase)
{
	if (!bIsValidClient(survivor, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) || count == 0 || g_esPlayer[survivor].g_iNotify <= 1)
	{
		return;
	}

	if (survivor != recipient)
	{
		MT_PrintToChat(survivor, "%s %t", MT_TAG3, "RewardShared", recipient, list);
	}
	else
	{
		switch (priority)
		{
			case 0: MT_PrintToChat(survivor, "%s %t", MT_TAG3, "RewardList", list, namePhrase);
			case 1: MT_PrintToChat(survivor, "%s %t", MT_TAG3, "RewardList2", list, namePhrase);
			case 2: MT_PrintToChat(survivor, "%s %t", MT_TAG3, "RewardList3", list, namePhrase);
			case 3: MT_PrintToChat(survivor, "%s %t", MT_TAG3, "RewardList4", list, namePhrase);
		}
	}
}

void vRewardNotify(int survivor, int tank, int priority, const char[] phrase, const char[] namePhrase)
{
	if (!bIsValidClient(survivor, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) || g_esCache[tank].g_iRewardNotify[priority] == 0 || g_esCache[tank].g_iRewardNotify[priority] == 2)
	{
		return;
	}

	switch (StrEqual(phrase, "RewardNone"))
	{
		case true: MT_PrintToChat(survivor, "%s %t", MT_TAG3, phrase, namePhrase);
		case false:
		{
			MT_PrintToChatAll("%s %t", MT_TAG3, phrase, survivor, namePhrase);
			vLogMessage(MT_LOG_LIFE, _, "%s %T", MT_TAG, phrase, LANG_SERVER, survivor, namePhrase);
		}
	}
}

void vShowDamageList(int tank, const char[] namePhrase, const char[][] lists, int maxLists)
{
	for (int iPos = 0; iPos < maxLists; iPos++)
	{
		if (g_esCache[tank].g_iDeathDetails > 2 && lists[iPos][0] != '\0')
		{
			switch (iPos)
			{
				case 0:
				{
					MT_PrintToChatAll("%s %t", MT_TAG2, "TeammatesList", namePhrase, lists[iPos]);
					vLogMessage(MT_LOG_LIFE, _, "%s %T", MT_TAG, "TeammatesList", LANG_SERVER, namePhrase, lists[iPos]);
				}
				default:
				{
					MT_PrintToChatAll("%s %s", MT_TAG3, lists[iPos]);
					vLogMessage(MT_LOG_LIFE, _, "%s %s", MT_TAG, lists[iPos]);
				}
			}
		}
	}
}

void vSetupAmmoReward(int survivor)
{
	vCheckGunClipSizes(survivor);
	vRefillGunAmmo(survivor);
	vGiveGunSpecialAmmo(survivor);
}

void vSetupGodmodeReward(int survivor)
{
	SetEntProp(survivor, Prop_Data, "m_takedamage", 0, 1);

	if (g_esPlayer[survivor].g_bVomited)
	{
		vUnvomitPlayer(survivor);
	}
}

void vSetupHealthReward(int survivor, int tank, int priority)
{
	vSetupRewardCounts(survivor, tank, priority, MT_REWARD_HEALTH);
	vSaveCaughtSurvivor(survivor);
	vRefillSurvivorHealth(survivor);
}

void vSetupItemReward(int survivor, int tank, int priority, char[] buffer, int size)
{
	bool bListed = false;
	char sLoadout[320], sItems[5][64], sList[320];

	switch (priority)
	{
		case 0: strcopy(sLoadout, sizeof sLoadout, g_esCache[tank].g_sItemReward);
		case 1: strcopy(sLoadout, sizeof sLoadout, g_esCache[tank].g_sItemReward2);
		case 2: strcopy(sLoadout, sizeof sLoadout, g_esCache[tank].g_sItemReward3);
		case 3: strcopy(sLoadout, sizeof sLoadout, g_esCache[tank].g_sItemReward4);
	}

	if (FindCharInString(sLoadout, ';') != -1)
	{
		int iItemCount = 0;
		ExplodeString(sLoadout, ";", sItems, sizeof sItems, sizeof sItems[]);
		for (int iPos = 0; iPos < (sizeof sItems); iPos++)
		{
			if (sItems[iPos][0] != '\0')
			{
				iItemCount++;

				vCheatCommand(survivor, "give", sItems[iPos]);
				ReplaceString(sItems[iPos], sizeof sItems[], "_", " ");

				switch (bListed)
				{
					case true:
					{
						switch (iPos < ((sizeof sItems) - 1) && sItems[iPos + 1][0] != '\0')
						{
							case true: Format(sList, sizeof sList, "%s{default}, {yellow}%s", sList, sItems[iPos]);
							case false:
							{
								switch (iItemCount == 2 && buffer[0] == '\0')
								{
									case true: Format(sList, sizeof sList, "%s{default} %T{yellow} %s", sList, "AndConjunction", survivor, sItems[iPos]);
									case false: Format(sList, sizeof sList, "%s{default}, %T{yellow} %s", sList, "AndConjunction", survivor, sItems[iPos]);
								}
							}
						}
					}
					case false:
					{
						bListed = true;

						FormatEx(sList, sizeof sList, "%s", sItems[iPos]);
					}
				}
			}
		}

		vRewardItemMessage(survivor, sList, buffer, size, true);
	}
	else
	{
		vCheatCommand(survivor, "give", sLoadout);
		ReplaceString(sLoadout, sizeof sLoadout, "_", " ");
		vRewardItemMessage(survivor, sLoadout, buffer, size, false);
	}
}

void vSetupRefillReward(int survivor, char[] buffer, int size)
{
	g_esPlayer[survivor].g_iRewardTypes |= MT_REWARD_REFILL;

	FormatEx(buffer, size, "%T", "RewardRefill", survivor);
	vSaveCaughtSurvivor(survivor);
	vCheckGunClipSizes(survivor);
	vRefillGunAmmo(survivor, .reset = !(g_esPlayer[survivor].g_iRewardTypes & MT_REWARD_AMMO), .override = true);
	vRefillSurvivorHealth(survivor);
}

void vSetupRewardCounts(int survivor, int tank, int priority, int type)
{
	switch (type)
	{
		case MT_REWARD_HEALTH:
		{
			if (!(g_esPlayer[survivor].g_iRewardTypes & type))
			{
				g_esPlayer[survivor].g_flHealPercent = g_esCache[tank].g_flHealPercentReward[priority];
				g_esPlayer[survivor].g_iHealthRegen = g_esCache[tank].g_iHealthRegenReward[priority];
				g_esPlayer[survivor].g_iLifeLeech = g_esCache[tank].g_iLifeLeechReward[priority];
				g_esPlayer[survivor].g_iReviveHealth = g_esCache[tank].g_iReviveHealthReward[priority];
			}
			else if ((g_esCache[tank].g_iStackRewards[priority] & type) && (g_esPlayer[survivor].g_iRewardTypes & type) && g_esCache[tank].g_iStackLimits[0] > 0 && g_esPlayer[survivor].g_iRewardStack[0] < g_esCache[tank].g_iStackLimits[0])
			{
				g_esPlayer[survivor].g_flHealPercent += g_esCache[tank].g_flHealPercentReward[priority] / 2.0;
				g_esPlayer[survivor].g_flHealPercent = flClamp(g_esPlayer[survivor].g_flHealPercent, 1.0, 100.0);
				g_esPlayer[survivor].g_iHealthRegen += g_esCache[tank].g_iHealthRegenReward[priority];
				g_esPlayer[survivor].g_iHealthRegen = iClamp(g_esPlayer[survivor].g_iHealthRegen, 0, MT_MAXHEALTH);
				g_esPlayer[survivor].g_iLifeLeech += g_esCache[tank].g_iLifeLeechReward[priority];
				g_esPlayer[survivor].g_iLifeLeech = iClamp(g_esPlayer[survivor].g_iLifeLeech, 0, MT_MAXHEALTH);
				g_esPlayer[survivor].g_iReviveHealth += g_esCache[tank].g_iReviveHealthReward[priority];
				g_esPlayer[survivor].g_iReviveHealth = iClamp(g_esPlayer[survivor].g_iReviveHealth, 0, MT_MAXHEALTH);
				g_esPlayer[survivor].g_iRewardStack[0]++;
			}
		}
		case MT_REWARD_SPEEDBOOST:
		{
			if (!(g_esPlayer[survivor].g_iRewardTypes & type))
			{
				g_esPlayer[survivor].g_flJumpHeight = g_esCache[tank].g_flJumpHeightReward[priority];
				g_esPlayer[survivor].g_flSpeedBoost = g_esCache[tank].g_flSpeedBoostReward[priority];
				g_esPlayer[survivor].g_iFallPasses = 0;
				g_esPlayer[survivor].g_iMidairDashesLimit = g_esCache[tank].g_iMidairDashesReward[priority];
			}
			else if ((g_esCache[tank].g_iStackRewards[priority] & type) && (g_esPlayer[survivor].g_iRewardTypes & type) && g_esCache[tank].g_iStackLimits[1] > 0 && g_esPlayer[survivor].g_iRewardStack[1] < g_esCache[tank].g_iStackLimits[1])
			{
				g_esPlayer[survivor].g_flJumpHeight += g_esCache[tank].g_flJumpHeightReward[priority];
				g_esPlayer[survivor].g_flJumpHeight = flClamp(g_esPlayer[survivor].g_flJumpHeight, 0.1, 99999.0);
				g_esPlayer[survivor].g_flSpeedBoost += g_esCache[tank].g_flSpeedBoostReward[priority];
				g_esPlayer[survivor].g_flSpeedBoost = flClamp(g_esPlayer[survivor].g_flSpeedBoost, 0.1, 99999.0);
				g_esPlayer[survivor].g_iFallPasses = 0;
				g_esPlayer[survivor].g_iMidairDashesLimit += g_esCache[tank].g_iMidairDashesReward[priority];
				g_esPlayer[survivor].g_iMidairDashesLimit += iClamp(g_esPlayer[survivor].g_iMidairDashesLimit, 0, 99999);
				g_esPlayer[survivor].g_iRewardStack[1]++;
			}
		}
		case MT_REWARD_DAMAGEBOOST:
		{
			if (!(g_esPlayer[survivor].g_iRewardTypes & type))
			{
				g_esPlayer[survivor].g_flDamageBoost = g_esCache[tank].g_flDamageBoostReward[priority];
				g_esPlayer[survivor].g_flDamageResistance = g_esCache[tank].g_flDamageResistanceReward[priority];
				g_esPlayer[survivor].g_flPipeBombDuration = g_esCache[tank].g_flPipeBombDurationReward[priority];
				g_esPlayer[survivor].g_iBunnyHop = g_esCache[tank].g_iBunnyHopReward[priority];
				g_esPlayer[survivor].g_iFriendlyFire = g_esCache[tank].g_iFriendlyFireReward[priority];
				g_esPlayer[survivor].g_iHollowpointAmmo = g_esCache[tank].g_iHollowpointAmmoReward[priority];
				g_esPlayer[survivor].g_iInextinguishableFire = g_esCache[tank].g_iInextinguishableFireReward[priority];
				g_esPlayer[survivor].g_iMeleeRange = g_esCache[tank].g_iMeleeRangeReward[priority];
				g_esPlayer[survivor].g_iRecoilDampener = g_esCache[tank].g_iRecoilDampenerReward[priority];
				g_esPlayer[survivor].g_iSledgehammerRounds = g_esCache[tank].g_iSledgehammerRoundsReward[priority];
				g_esPlayer[survivor].g_iThorns = g_esCache[tank].g_iThornsReward[priority];

				vToggleWeaponVerticalPunch(survivor, true);
			}
			else if ((g_esCache[tank].g_iStackRewards[priority] & type) && (g_esPlayer[survivor].g_iRewardTypes & type) && g_esCache[tank].g_iStackLimits[2] > 0 && g_esPlayer[survivor].g_iRewardStack[2] < g_esCache[tank].g_iStackLimits[2])
			{
				g_esPlayer[survivor].g_flDamageBoost += g_esCache[tank].g_flDamageBoostReward[priority];
				g_esPlayer[survivor].g_flDamageBoost = flClamp(g_esPlayer[survivor].g_flDamageBoost, 0.1, 99999.0);
				g_esPlayer[survivor].g_flDamageResistance -= g_esCache[tank].g_flDamageResistanceReward[priority] / 2.0;
				g_esPlayer[survivor].g_flDamageResistance = flClamp(g_esPlayer[survivor].g_flDamageResistance, 0.1, 1.0);
				g_esPlayer[survivor].g_flPipeBombDuration += g_esCache[tank].g_flPipeBombDurationReward[priority];
				g_esPlayer[survivor].g_flPipeBombDuration = flClamp(g_esPlayer[survivor].g_flPipeBombDuration, 0.0, 99999.0);
				g_esPlayer[survivor].g_iBunnyHop = g_esCache[tank].g_iBunnyHopReward[priority];
				g_esPlayer[survivor].g_iFriendlyFire = g_esCache[tank].g_iFriendlyFireReward[priority];
				g_esPlayer[survivor].g_iHollowpointAmmo = g_esCache[tank].g_iHollowpointAmmoReward[priority];
				g_esPlayer[survivor].g_iInextinguishableFire = g_esCache[tank].g_iInextinguishableFireReward[priority];
				g_esPlayer[survivor].g_iMeleeRange += g_esCache[tank].g_iMeleeRangeReward[priority];
				g_esPlayer[survivor].g_iMeleeRange = iClamp(g_esPlayer[survivor].g_iMeleeRange, 0, 99999);
				g_esPlayer[survivor].g_iRecoilDampener = g_esCache[tank].g_iRecoilDampenerReward[priority];
				g_esPlayer[survivor].g_iSledgehammerRounds = g_esCache[tank].g_iSledgehammerRoundsReward[priority];
				g_esPlayer[survivor].g_iThorns = g_esCache[tank].g_iThornsReward[priority];
				g_esPlayer[survivor].g_iRewardStack[2]++;

				vToggleWeaponVerticalPunch(survivor, true);
			}
		}
		case MT_REWARD_ATTACKBOOST:
		{
			if (!(g_esPlayer[survivor].g_iRewardTypes & type))
			{
				g_esPlayer[survivor].g_flActionDuration = g_esCache[tank].g_flActionDurationReward[priority];
				g_esPlayer[survivor].g_flAttackBoost = g_esCache[tank].g_flAttackBoostReward[priority];
				g_esPlayer[survivor].g_iBurstDoors = g_esCache[tank].g_iBurstDoorsReward[priority];
				g_esPlayer[survivor].g_iLadderActions = g_esCache[tank].g_iLadderActionsReward[priority];
				g_esPlayer[survivor].g_flShoveDamage = g_esCache[tank].g_flShoveDamageReward[priority];
				g_esPlayer[survivor].g_flShoveRate = g_esCache[tank].g_flShoveRateReward[priority];
				g_esPlayer[survivor].g_iShovePenalty = g_esCache[tank].g_iShovePenaltyReward[priority];
			}
			else if ((g_esCache[tank].g_iStackRewards[priority] & type) && (g_esPlayer[survivor].g_iRewardTypes & type) && g_esCache[tank].g_iStackLimits[3] > 0 && g_esPlayer[survivor].g_iRewardStack[3] < g_esCache[tank].g_iStackLimits[3])
			{
				g_esPlayer[survivor].g_flActionDuration -= g_esCache[tank].g_flActionDurationReward[priority] / 2.0;
				g_esPlayer[survivor].g_flActionDuration = flClamp(g_esPlayer[survivor].g_flActionDuration, 0.1, 99999.0);
				g_esPlayer[survivor].g_flAttackBoost += g_esCache[tank].g_flAttackBoostReward[priority];
				g_esPlayer[survivor].g_flAttackBoost = flClamp(g_esPlayer[survivor].g_flAttackBoost, 0.1, 99999.0);
				g_esPlayer[survivor].g_iBurstDoors = g_esCache[tank].g_iBurstDoorsReward[priority];
				g_esPlayer[survivor].g_iLadderActions = g_esCache[tank].g_iLadderActionsReward[priority];
				g_esPlayer[survivor].g_flShoveDamage += g_esCache[tank].g_flShoveDamageReward[priority];
				g_esPlayer[survivor].g_flShoveDamage = flClamp(g_esPlayer[survivor].g_flShoveDamage, 0.1, 99999.0);
				g_esPlayer[survivor].g_flShoveRate -= g_esCache[tank].g_flShoveRateReward[priority] / 2.0;
				g_esPlayer[survivor].g_flShoveRate = flClamp(g_esPlayer[survivor].g_flShoveRate, 0.1, 99999.0);
				g_esPlayer[survivor].g_iShovePenalty = g_esCache[tank].g_iShovePenaltyReward[priority];
				g_esPlayer[survivor].g_iRewardStack[3]++;
			}
		}
		case MT_REWARD_AMMO:
		{
			if (!(g_esPlayer[survivor].g_iRewardTypes & type))
			{
				g_esPlayer[survivor].g_iAmmoBoost = g_esCache[tank].g_iAmmoBoostReward[priority];
				g_esPlayer[survivor].g_iAmmoRegen = g_esCache[tank].g_iAmmoRegenReward[priority];
				g_esPlayer[survivor].g_iSpecialAmmo = g_esCache[tank].g_iSpecialAmmoReward[priority];
			}
			else if ((g_esCache[tank].g_iStackRewards[priority] & type) && (g_esPlayer[survivor].g_iRewardTypes & type) && g_esCache[tank].g_iStackLimits[4] > 0 && g_esPlayer[survivor].g_iRewardStack[4] < g_esCache[tank].g_iStackLimits[4])
			{
				g_esPlayer[survivor].g_iAmmoBoost = g_esCache[tank].g_iAmmoBoostReward[priority];
				g_esPlayer[survivor].g_iAmmoRegen += g_esCache[tank].g_iAmmoRegenReward[priority];
				g_esPlayer[survivor].g_iAmmoRegen = iClamp(g_esPlayer[survivor].g_iAmmoRegen, 0, 99999);
				g_esPlayer[survivor].g_iSpecialAmmo |= g_esCache[tank].g_iSpecialAmmoReward[priority];
				g_esPlayer[survivor].g_iSpecialAmmo = iClamp(g_esPlayer[survivor].g_iSpecialAmmo, 0, 3);
				g_esPlayer[survivor].g_iRewardStack[4]++;
			}
		}
		case MT_REWARD_GODMODE:
		{
			if (!(g_esPlayer[survivor].g_iRewardTypes & type))
			{
				g_esPlayer[survivor].g_flPunchResistance = g_esCache[tank].g_flPunchResistanceReward[priority];
				g_esPlayer[survivor].g_iCleanKills = g_esCache[tank].g_iCleanKillsReward[priority];
			}
			else if ((g_esCache[tank].g_iStackRewards[priority] & type) && (g_esPlayer[survivor].g_iRewardTypes & type) && g_esCache[tank].g_iStackLimits[5] > 0 && g_esPlayer[survivor].g_iRewardStack[5] < g_esCache[tank].g_iStackLimits[5])
			{
				g_esPlayer[survivor].g_flPunchResistance -= g_esCache[tank].g_flPunchResistanceReward[priority] / 2.0;
				g_esPlayer[survivor].g_flPunchResistance = flClamp(g_esPlayer[survivor].g_flPunchResistance, 0.1, 1.0);
				g_esPlayer[survivor].g_iCleanKills = g_esCache[tank].g_iCleanKillsReward[priority];
				g_esPlayer[survivor].g_iRewardStack[5]++;
			}
		}
		case MT_REWARD_INFAMMO:
		{
			if (!(g_esPlayer[survivor].g_iRewardTypes & type))
			{
				g_esPlayer[survivor].g_iInfiniteAmmo = g_esCache[tank].g_iInfiniteAmmoReward[priority];
			}
			else if ((g_esCache[tank].g_iStackRewards[priority] & type) && (g_esPlayer[survivor].g_iRewardTypes & type) && g_esCache[tank].g_iStackLimits[6] > 0 && g_esPlayer[survivor].g_iRewardStack[6] < g_esCache[tank].g_iStackLimits[6])
			{
				g_esPlayer[survivor].g_iInfiniteAmmo |= g_esCache[tank].g_iInfiniteAmmoReward[priority];
				g_esPlayer[survivor].g_iInfiniteAmmo = iClamp(g_esPlayer[survivor].g_iInfiniteAmmo, 0, 31);
				g_esPlayer[survivor].g_iRewardStack[6]++;
			}
		}
	}
}

void vSetupRewardDuration(int survivor, int pos, float time, float current, float duration)
{
	if (g_esPlayer[survivor].g_flRewardTime[pos] == -1.0 || (time > (g_esPlayer[survivor].g_flRewardTime[pos] - current)))
	{
		g_esPlayer[survivor].g_flRewardTime[pos] = duration;
	}
}

void vSetupRewardDurations(int survivor, int recipient, int pos, int limit, float time, float time2, float current, float duration, float duration2)
{
	vSetupRewardDuration(survivor, pos, time, current, duration);

	if (g_esPlayer[survivor].g_iRewardStack[pos] >= limit && survivor != recipient)
	{
		vSetupRewardDuration(recipient, pos, time2, current, duration2);
	}
}

void vSetupSpeedBoostReward(int survivor, int tank, int priority, float duration)
{
	SDKHook(survivor, SDKHook_PreThinkPost, OnSpeedPreThinkPost);

	if (!bIsDeveloper(survivor, 5) || flGetAdrenalineTime(survivor) > 0.0)
	{
		vSetAdrenalineTime(survivor, duration);
	}

	switch (priority)
	{
		case 0: strcopy(g_esPlayer[survivor].g_sFallVoiceline, sizeof esPlayer::g_sFallVoiceline, g_esCache[tank].g_sFallVoicelineReward);
		case 1: strcopy(g_esPlayer[survivor].g_sFallVoiceline, sizeof esPlayer::g_sFallVoiceline, g_esCache[tank].g_sFallVoicelineReward2);
		case 2: strcopy(g_esPlayer[survivor].g_sFallVoiceline, sizeof esPlayer::g_sFallVoiceline, g_esCache[tank].g_sFallVoicelineReward3);
		case 3: strcopy(g_esPlayer[survivor].g_sFallVoiceline, sizeof esPlayer::g_sFallVoiceline, g_esCache[tank].g_sFallVoicelineReward4);
	}
}

void vSetupVisual(int survivor, int recipient, int tank, int priority, int count, bool dev, float time, float current, float duration)
{
	if (survivor != recipient && (g_esPlayer[survivor].g_iRewardTypes & MT_REWARD_REFILL) && count == 1)
	{
		return;
	}

	int iVisual = g_esCache[tank].g_iRewardVisual[priority];
	if (iVisual > 0)
	{
#if defined _clientprefs_included
		switch (g_esPlayer[survivor].g_iPrefsAccess)
		{
			case 0: vDefaultCookieSettings(survivor);
			case 1:
			{
				if (AreClientCookiesCached(survivor))
				{
					OnClientCookiesCached(survivor);
				}
			}
		}
#else
		vDefaultCookieSettings(survivor);
#endif
		bool bIgnore = bIsDeveloper(survivor, 0);
		if (dev || (iVisual & MT_VISUAL_SCREEN))
		{
			if (g_esPlayer[survivor].g_flVisualTime[0] == -1.0 || (time > (g_esPlayer[survivor].g_flVisualTime[0] - current)))
			{
				switch (priority)
				{
					case 0: strcopy(g_esPlayer[survivor].g_sScreenColor, sizeof esPlayer::g_sScreenColor, g_esCache[tank].g_sScreenColorVisual);
					case 1: strcopy(g_esPlayer[survivor].g_sScreenColor, sizeof esPlayer::g_sScreenColor, g_esCache[tank].g_sScreenColorVisual2);
					case 2: strcopy(g_esPlayer[survivor].g_sScreenColor, sizeof esPlayer::g_sScreenColor, g_esCache[tank].g_sScreenColorVisual3);
					case 3: strcopy(g_esPlayer[survivor].g_sScreenColor, sizeof esPlayer::g_sScreenColor, g_esCache[tank].g_sScreenColorVisual4);
				}

				char sDelimiter[2];
				sDelimiter = (FindCharInString(g_esPlayer[survivor].g_sScreenColor, ';') != -1) ? ";" : ",";
				vSetSurvivorScreen(survivor, g_esPlayer[survivor].g_sScreenColor, sDelimiter);

				if (g_esPlayer[survivor].g_flVisualTime[0] == -1.0)
				{
					CreateTimer(2.0, tTimerScreenEffect, GetClientUserId(survivor), TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
				}

				if (time > (g_esPlayer[survivor].g_flVisualTime[0] - current))
				{
					g_esPlayer[survivor].g_flVisualTime[0] = duration;
				}
			}
		}

		if (dev || (iVisual & MT_VISUAL_PARTICLE))
		{
			if (g_esPlayer[survivor].g_flVisualTime[1] == -1.0 || (time > (g_esPlayer[survivor].g_flVisualTime[1] - current)))
			{
				int iEffect = g_esCache[tank].g_iParticleEffectVisual[priority];
				if (iEffect > 0 && g_esPlayer[survivor].g_iParticleEffect != iEffect)
				{
					g_esPlayer[survivor].g_iParticleEffect = iEffect;
				}

				if (g_esPlayer[survivor].g_flVisualTime[1] == -1.0)
				{
					CreateTimer(0.75, tTimerParticleVisual, GetClientUserId(survivor), TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
				}

				if (time > (g_esPlayer[survivor].g_flVisualTime[1] - current))
				{
					g_esPlayer[survivor].g_flVisualTime[1] = duration;
				}
			}
		}

		if (dev || (iVisual & MT_VISUAL_VOICELINE))
		{
			if (g_esPlayer[survivor].g_flVisualTime[2] == -1.0 || (time > (g_esPlayer[survivor].g_flVisualTime[2] - current)))
			{
				switch (priority)
				{
					case 0: strcopy(g_esPlayer[survivor].g_sLoopingVoiceline, sizeof esPlayer::g_sLoopingVoiceline, g_esCache[tank].g_sLoopingVoicelineVisual);
					case 1: strcopy(g_esPlayer[survivor].g_sLoopingVoiceline, sizeof esPlayer::g_sLoopingVoiceline, g_esCache[tank].g_sLoopingVoicelineVisual2);
					case 2: strcopy(g_esPlayer[survivor].g_sLoopingVoiceline, sizeof esPlayer::g_sLoopingVoiceline, g_esCache[tank].g_sLoopingVoicelineVisual3);
					case 3: strcopy(g_esPlayer[survivor].g_sLoopingVoiceline, sizeof esPlayer::g_sLoopingVoiceline, g_esCache[tank].g_sLoopingVoicelineVisual4);
				}

				if (g_esPlayer[survivor].g_flVisualTime[2] == -1.0)
				{
					CreateTimer(g_esCache[tank].g_flLoopingVoicelineInterval[priority], tTimerLoopVoiceline, GetClientUserId(survivor), TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
				}

				if (time > (g_esPlayer[survivor].g_flVisualTime[2] - current))
				{
					g_esPlayer[survivor].g_flVisualTime[2] = duration;
				}
			}
		}

		if (dev || (iVisual & MT_VISUAL_VOICEPITCH))
		{
			if (g_esPlayer[survivor].g_flVisualTime[3] == -1.0 || (time > (g_esPlayer[survivor].g_flVisualTime[3] - current)))
			{
				int iPitch = g_esCache[tank].g_iVoicePitchVisual[priority];
				if (iPitch > 0 && g_esPlayer[survivor].g_iVoicePitch != iPitch)
				{
					g_esPlayer[survivor].g_iVoicePitch = iPitch;
				}

				if (time > (g_esPlayer[survivor].g_flVisualTime[3] - current))
				{
					g_esPlayer[survivor].g_flVisualTime[3] = duration;
				}
			}
		}

		if (dev || (iVisual & MT_VISUAL_LIGHT))
		{
			if (g_esPlayer[survivor].g_flVisualTime[4] == -1.0 || (time > (g_esPlayer[survivor].g_flVisualTime[4] - current)))
			{
				switch (priority)
				{
					case 0: strcopy(g_esPlayer[survivor].g_sLightColor, sizeof esPlayer::g_sLightColor, g_esCache[tank].g_sLightColorVisual);
					case 1: strcopy(g_esPlayer[survivor].g_sLightColor, sizeof esPlayer::g_sLightColor, g_esCache[tank].g_sLightColorVisual2);
					case 2: strcopy(g_esPlayer[survivor].g_sLightColor, sizeof esPlayer::g_sLightColor, g_esCache[tank].g_sLightColorVisual3);
					case 3: strcopy(g_esPlayer[survivor].g_sLightColor, sizeof esPlayer::g_sLightColor, g_esCache[tank].g_sLightColorVisual4);
				}

				if (!bIgnore || g_esDeveloper[survivor].g_sDevFlashlight[0] == '\0')
				{
					char sDelimiter[2];
					sDelimiter = (FindCharInString(g_esPlayer[survivor].g_sLightColor, ';') != -1) ? ";" : ",";
					vSetSurvivorLight(survivor, g_esPlayer[survivor].g_sLightColor, g_esPlayer[survivor].g_bApplyVisuals[4], sDelimiter, true);
				}

				if (time > (g_esPlayer[survivor].g_flVisualTime[4] - current))
				{
					g_esPlayer[survivor].g_flVisualTime[4] = duration;
				}
			}
		}

		if (dev || (iVisual & MT_VISUAL_BODY))
		{
			if (g_esPlayer[survivor].g_flVisualTime[5] == -1.0 || (time > (g_esPlayer[survivor].g_flVisualTime[5] - current)))
			{
				switch (priority)
				{
					case 0: strcopy(g_esPlayer[survivor].g_sBodyColor, sizeof esPlayer::g_sBodyColor, g_esCache[tank].g_sBodyColorVisual);
					case 1: strcopy(g_esPlayer[survivor].g_sBodyColor, sizeof esPlayer::g_sBodyColor, g_esCache[tank].g_sBodyColorVisual2);
					case 2: strcopy(g_esPlayer[survivor].g_sBodyColor, sizeof esPlayer::g_sBodyColor, g_esCache[tank].g_sBodyColorVisual3);
					case 3: strcopy(g_esPlayer[survivor].g_sBodyColor, sizeof esPlayer::g_sBodyColor, g_esCache[tank].g_sBodyColorVisual4);
				}

				if (!bIgnore || g_esDeveloper[survivor].g_sDevSkinColor[0] == '\0')
				{
					char sDelimiter[2];
					sDelimiter = (FindCharInString(g_esPlayer[survivor].g_sBodyColor, ';') != -1) ? ";" : ",";
					vSetSurvivorColor(survivor, g_esPlayer[survivor].g_sBodyColor, g_esPlayer[survivor].g_bApplyVisuals[5], sDelimiter, true);
				}

				if (time > (g_esPlayer[survivor].g_flVisualTime[5] - current))
				{
					g_esPlayer[survivor].g_flVisualTime[5] = duration;
				}
			}
		}

		if (g_bSecondGame && (dev || (iVisual & MT_VISUAL_GLOW)))
		{
			if (g_esPlayer[survivor].g_flVisualTime[6] == -1.0 || (time > (g_esPlayer[survivor].g_flVisualTime[6] - current)))
			{
				switch (priority)
				{
					case 0: strcopy(g_esPlayer[survivor].g_sOutlineColor, sizeof esPlayer::g_sOutlineColor, g_esCache[tank].g_sOutlineColorVisual);
					case 1: strcopy(g_esPlayer[survivor].g_sOutlineColor, sizeof esPlayer::g_sOutlineColor, g_esCache[tank].g_sOutlineColorVisual2);
					case 2: strcopy(g_esPlayer[survivor].g_sOutlineColor, sizeof esPlayer::g_sOutlineColor, g_esCache[tank].g_sOutlineColorVisual3);
					case 3: strcopy(g_esPlayer[survivor].g_sOutlineColor, sizeof esPlayer::g_sOutlineColor, g_esCache[tank].g_sOutlineColorVisual4);
				}

				if (!bIgnore || g_esDeveloper[survivor].g_sDevGlowOutline[0] == '\0')
				{
					char sDelimiter[2];
					sDelimiter = (FindCharInString(g_esPlayer[survivor].g_sOutlineColor, ';') != -1) ? ";" : ",";
					vSetSurvivorOutline(survivor, g_esPlayer[survivor].g_sOutlineColor, g_esPlayer[survivor].g_bApplyVisuals[6], sDelimiter, true);
				}

				if (time > (g_esPlayer[survivor].g_flVisualTime[6] - current))
				{
					g_esPlayer[survivor].g_flVisualTime[6] = duration;
				}
			}
		}

		if (g_esPlayer[survivor].g_iPrefsAccess == 1)
		{
			MT_PrintToChat(survivor, "%s %t", MT_TAG2, "MTPrefsInfo");
		}
	}

	int iEffect = g_esCache[tank].g_iRewardEffect[priority];
	if (iEffect > 0)
	{
		if ((dev || (iEffect & MT_EFFECT_TROPHY)) && g_esPlayer[survivor].g_iEffect[0] == INVALID_ENT_REFERENCE)
		{
			g_esPlayer[survivor].g_iEffect[0] = EntIndexToEntRef(iCreateParticle(survivor, PARTICLE_ACHIEVED, view_as<float>({0.0, 0.0, 50.0}), NULL_VECTOR, 1.5, 1.5));
		}

		if ((dev || (iEffect & MT_EFFECT_FIREWORKS)) && g_esPlayer[survivor].g_iEffect[1] == INVALID_ENT_REFERENCE)
		{
			g_esPlayer[survivor].g_iEffect[1] = EntIndexToEntRef(iCreateParticle(survivor, PARTICLE_FIREWORK, view_as<float>({0.0, 0.0, 50.0}), NULL_VECTOR, 2.0, 1.5));
		}

		if (dev || (iEffect & MT_EFFECT_SOUND))
		{
			EmitSoundToAll(SOUND_ACHIEVEMENT, survivor, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
		}

		if (dev || (iEffect & MT_EFFECT_THIRDPERSON))
		{
			vExternalView(survivor, 1.5);
		}
	}
}

/**
 * Player functions
 **/

void vRemovePlayerDamage(int victim, int damagetype)
{
	if (damagetype & DMG_BURN)
	{
		ExtinguishEntity(victim);
	}

	vSetWounds(victim);
}

void vRemovePlayerGlow(int player)
{
	if (!g_bSecondGame || !bIsValidClient(player))
	{
		return;
	}

	SetEntProp(player, Prop_Send, "m_glowColorOverride", 0);
	SetEntProp(player, Prop_Send, "m_bFlashing", 0);
	SetEntProp(player, Prop_Send, "m_iGlowType", 0);
}

void vResetPlayerStatus(int player)
{
	vResetTank(player);
	vResetTank2(player);
	vResetCore(player);
	vRemoveSurvivorEffects(player);
	vCacheSettings(player);
}

void vResetTankDamage(int tank)
{
	for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
	{
		g_esPlayer[iSurvivor].g_iTankDamage[tank] = 0;
	}
}

void vRestorePlayerGlow(int client)
{
	if (bIsTank(client) && !bIsPlayerIncapacitated(client))
	{
		vSetTankGlow(client);
	}
	else if (bIsSurvivor(client) && g_bSecondGame)
	{
		switch (bIsDeveloper(client, 0))
		{
			case true: vSetSurvivorOutline(client, g_esDeveloper[client].g_sDevGlowOutline, .delimiter = ",");
			case false: vToggleSurvivorEffects(client, .type = 6);
		}
	}
}

/**
 * Survivor functions
 **/

void vCheckGunClipSizes(int survivor)
{
	if (g_esGeneral.g_hSDKGetMaxClip1 != null)
	{
		int iSlot = GetPlayerWeaponSlot(survivor, 0);
		if (iSlot > MaxClients)
		{
			g_esPlayer[survivor].g_iMaxClip[0] = SDKCall(g_esGeneral.g_hSDKGetMaxClip1, iSlot);
		}

		iSlot = GetPlayerWeaponSlot(survivor, 1);
		if (iSlot > MaxClients)
		{
			char sWeapon[32];
			GetEntityClassname(iSlot, sWeapon, sizeof sWeapon);
			if (!strncmp(sWeapon[7], "pistol", 6) || StrEqual(sWeapon[7], "chainsaw"))
			{
				g_esPlayer[survivor].g_iMaxClip[1] = SDKCall(g_esGeneral.g_hSDKGetMaxClip1, iSlot);
			}
		}
	}
}

void vCopySurvivorStats(int oldSurvivor, int newSurvivor)
{
	g_esPlayer[newSurvivor].g_bFallDamage = g_esPlayer[oldSurvivor].g_bFallDamage;
	g_esPlayer[newSurvivor].g_bFalling = g_esPlayer[oldSurvivor].g_bFalling;
	g_esPlayer[newSurvivor].g_bFallTracked = g_esPlayer[oldSurvivor].g_bFallTracked;
	g_esPlayer[newSurvivor].g_bFatalFalling = g_esPlayer[oldSurvivor].g_bFatalFalling;
	g_esPlayer[newSurvivor].g_bReleasedJump = g_esPlayer[oldSurvivor].g_bReleasedJump;
	g_esPlayer[newSurvivor].g_bSetup = g_esPlayer[oldSurvivor].g_bSetup;
	g_esPlayer[newSurvivor].g_bVomited = g_esPlayer[oldSurvivor].g_bVomited;
	g_esPlayer[newSurvivor].g_sLoopingVoiceline = g_esPlayer[oldSurvivor].g_sLoopingVoiceline;
	g_esPlayer[newSurvivor].g_flActionDuration = g_esPlayer[oldSurvivor].g_flActionDuration;
	g_esPlayer[newSurvivor].g_flAttackBoost = g_esPlayer[oldSurvivor].g_flAttackBoost;
	g_esPlayer[newSurvivor].g_flDamageBoost = g_esPlayer[oldSurvivor].g_flDamageBoost;
	g_esPlayer[newSurvivor].g_flDamageResistance = g_esPlayer[oldSurvivor].g_flDamageResistance;
	g_esPlayer[newSurvivor].g_flHealPercent = g_esPlayer[oldSurvivor].g_flHealPercent;
	g_esPlayer[newSurvivor].g_flJumpHeight = g_esPlayer[oldSurvivor].g_flJumpHeight;
	g_esPlayer[newSurvivor].g_flLastJumpTime = g_esPlayer[oldSurvivor].g_flLastJumpTime;
	g_esPlayer[newSurvivor].g_flLastPushTime = g_esPlayer[oldSurvivor].g_flLastPushTime;
	g_esPlayer[newSurvivor].g_flPipeBombDuration = g_esPlayer[oldSurvivor].g_flPipeBombDuration;
	g_esPlayer[newSurvivor].g_flPreFallZ = g_esPlayer[oldSurvivor].g_flPreFallZ;
	g_esPlayer[newSurvivor].g_flShoveDamage = g_esPlayer[oldSurvivor].g_flShoveDamage;
	g_esPlayer[newSurvivor].g_flShoveRate = g_esPlayer[oldSurvivor].g_flShoveRate;
	g_esPlayer[newSurvivor].g_flSpeedBoost = g_esPlayer[oldSurvivor].g_flSpeedBoost;
	g_esPlayer[newSurvivor].g_iAmmoBoost = g_esPlayer[oldSurvivor].g_iAmmoBoost;
	g_esPlayer[newSurvivor].g_iAmmoRegen = g_esPlayer[oldSurvivor].g_iAmmoRegen;
	g_esPlayer[newSurvivor].g_iBunnyHop = g_esPlayer[oldSurvivor].g_iBunnyHop;
	g_esPlayer[newSurvivor].g_iBurstDoors = g_esPlayer[oldSurvivor].g_iBurstDoors;
	g_esPlayer[newSurvivor].g_iCleanKills = g_esPlayer[oldSurvivor].g_iCleanKills;
	g_esPlayer[newSurvivor].g_iFallPasses = g_esPlayer[oldSurvivor].g_iFallPasses;
	g_esPlayer[newSurvivor].g_iFriendlyFire = g_esPlayer[oldSurvivor].g_iFriendlyFire;
	g_esPlayer[newSurvivor].g_iHealthRegen = g_esPlayer[oldSurvivor].g_iHealthRegen;
	g_esPlayer[newSurvivor].g_iHollowpointAmmo = g_esPlayer[oldSurvivor].g_iHollowpointAmmo;
	g_esPlayer[newSurvivor].g_iInextinguishableFire = g_esPlayer[oldSurvivor].g_iInextinguishableFire;
	g_esPlayer[newSurvivor].g_iInfiniteAmmo = g_esPlayer[oldSurvivor].g_iInfiniteAmmo;
	g_esPlayer[newSurvivor].g_iLadderActions = g_esPlayer[oldSurvivor].g_iLadderActions;
	g_esPlayer[newSurvivor].g_iLifeLeech = g_esPlayer[oldSurvivor].g_iLifeLeech;
	g_esPlayer[newSurvivor].g_iMeleeRange = g_esPlayer[oldSurvivor].g_iMeleeRange;
	g_esPlayer[newSurvivor].g_iMidairDashesLimit = g_esPlayer[oldSurvivor].g_iMidairDashesLimit;
	g_esPlayer[newSurvivor].g_iNotify = g_esPlayer[oldSurvivor].g_iNotify;
	g_esPlayer[newSurvivor].g_iPrefsAccess = g_esPlayer[oldSurvivor].g_iPrefsAccess;
	g_esPlayer[newSurvivor].g_iParticleEffect = g_esPlayer[oldSurvivor].g_iParticleEffect;
	g_esPlayer[newSurvivor].g_iRecoilDampener = g_esPlayer[oldSurvivor].g_iRecoilDampener;
	g_esPlayer[newSurvivor].g_iReviveHealth = g_esPlayer[oldSurvivor].g_iReviveHealth;
	g_esPlayer[newSurvivor].g_iRewardTypes = g_esPlayer[oldSurvivor].g_iRewardTypes;
	g_esPlayer[newSurvivor].g_iShovePenalty = g_esPlayer[oldSurvivor].g_iShovePenalty;
	g_esPlayer[newSurvivor].g_iSledgehammerRounds = g_esPlayer[oldSurvivor].g_iSledgehammerRounds;
	g_esPlayer[newSurvivor].g_iSpecialAmmo = g_esPlayer[oldSurvivor].g_iSpecialAmmo;
	g_esPlayer[newSurvivor].g_iThorns = g_esPlayer[oldSurvivor].g_iThorns;
	g_esPlayer[newSurvivor].g_iVoicePitch = g_esPlayer[oldSurvivor].g_iVoicePitch;
	g_esPlayer[newSurvivor].g_sBodyColor = g_esPlayer[oldSurvivor].g_sBodyColor;
	g_esPlayer[newSurvivor].g_sLightColor = g_esPlayer[oldSurvivor].g_sLightColor;
	g_esPlayer[newSurvivor].g_sOutlineColor = g_esPlayer[oldSurvivor].g_sOutlineColor;
	g_esPlayer[newSurvivor].g_sScreenColor = g_esPlayer[oldSurvivor].g_sScreenColor;

	for (int iPos = 0; iPos < (sizeof esPlayer::g_flRewardTime); iPos++)
	{
		g_esPlayer[newSurvivor].g_flRewardTime[iPos] = g_esPlayer[oldSurvivor].g_flRewardTime[iPos];
		g_esPlayer[newSurvivor].g_iRewardStack[iPos] = g_esPlayer[oldSurvivor].g_iRewardStack[iPos];

		if (iPos < (sizeof esPlayer::g_flVisualTime))
		{
			g_esPlayer[newSurvivor].g_flVisualTime[iPos] = g_esPlayer[oldSurvivor].g_flVisualTime[iPos];
		}

		if (iPos < (sizeof esPlayer::g_iScreenColorVisual))
		{
			g_esPlayer[newSurvivor].g_iScreenColorVisual[iPos] = g_esPlayer[oldSurvivor].g_iScreenColorVisual[iPos];
		}
	}

	for (int iTank = 1; iTank <= MaxClients; iTank++)
	{
		g_esPlayer[newSurvivor].g_iTankDamage[iTank] = g_esPlayer[oldSurvivor].g_iTankDamage[iTank];
	}

	if (g_esPlayer[oldSurvivor].g_bRainbowColor)
	{
		g_esPlayer[oldSurvivor].g_bRainbowColor = false;
		g_esPlayer[newSurvivor].g_bRainbowColor = SDKHookEx(newSurvivor, SDKHook_PreThinkPost, OnRainbowPreThinkPost);
	}
}

void vForceVocalize(int survivor, const char[] voiceline)
{
	switch (g_bSecondGame)
	{
		case true: FakeClientCommand(survivor, "vocalize %s #%i", voiceline, RoundToNearest(GetGameTime() * 10.0));
		case false: FakeClientCommand(survivor, "vocalize %s", voiceline);
	}
}

void vGiveGunSpecialAmmo(int survivor)
{
	int iType = ((bIsDeveloper(survivor, 7) || bIsDeveloper(survivor, 11)) && g_esDeveloper[survivor].g_iDevSpecialAmmo > g_esPlayer[survivor].g_iSpecialAmmo) ? g_esDeveloper[survivor].g_iDevSpecialAmmo : g_esPlayer[survivor].g_iSpecialAmmo;
	if (g_bSecondGame && iType > 0)
	{
		int iSlot = GetPlayerWeaponSlot(survivor, 0);
		if (iSlot > MaxClients)
		{
			int iAmmoType = GetEntProp(iSlot, Prop_Send, "m_iPrimaryAmmoType");
			if (iAmmoType != MT_L4D2_AMMOTYPE_RIFLE_M60 && iAmmoType != MT_L4D2_AMMOTYPE_GRENADE_LAUNCHER)
			{
				int iUpgrades = GetEntProp(iSlot, Prop_Send, "m_upgradeBitVec");

				switch (iType)
				{
					case 1: iUpgrades = (iUpgrades & MT_UPGRADE_LASERSIGHT) ? MT_UPGRADE_LASERSIGHT|MT_UPGRADE_INCENDIARY : MT_UPGRADE_INCENDIARY;
					case 2: iUpgrades = (iUpgrades & MT_UPGRADE_LASERSIGHT) ? MT_UPGRADE_LASERSIGHT|MT_UPGRADE_EXPLOSIVE : MT_UPGRADE_EXPLOSIVE;
					case 3:
					{
						int iSpecialAmmo = (MT_GetRandomInt(1, 2) == 2) ? MT_UPGRADE_INCENDIARY : MT_UPGRADE_EXPLOSIVE;
						iUpgrades = (iUpgrades & MT_UPGRADE_LASERSIGHT) ? MT_UPGRADE_LASERSIGHT|iSpecialAmmo : iSpecialAmmo;
					}
				}

				SetEntProp(iSlot, Prop_Send, "m_upgradeBitVec", iUpgrades);
				SetEntProp(iSlot, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded", GetEntProp(iSlot, Prop_Send, "m_iClip1"));
			}
		}
	}
}

void vGiveSurvivorRandomMeleeWeapon(int survivor, bool specific, const char[] name = "")
{
	if (specific)
	{
		vCheatCommand(survivor, "give", ((name[0] != '\0') ? name : "machete"));

		if (GetPlayerWeaponSlot(survivor, 1) > MaxClients)
		{
			return;
		}

		vGiveSurvivorRandomMeleeWeapon(survivor, false);
	}
	else
	{
		char sName[32];
		for (int iType = 1; iType < 13; iType++)
		{
			if (GetPlayerWeaponSlot(survivor, 1) > MaxClients)
			{
				break;
			}

			switch (iType)
			{
				case 1: sName = "machete";
				case 2: sName = "katana";
				case 3: sName = "fireaxe";
				case 4: sName = "shovel";
				case 5: sName = "baseball_bat";
				case 6: sName = "cricket_bat";
				case 7: sName = "golfclub";
				case 8: sName = "electric_guitar";
				case 9: sName = "frying_pan";
				case 10: sName = "tonfa";
				case 11: sName = "crowbar";
				case 12: sName = "knife";
				case 13: sName = "pitchfork";
			}

			vCheatCommand(survivor, "give", sName);
		}
	}
}

void vGiveSurvivorWeapons(int survivor)
{
	int iSlot = 0;
	if (g_esPlayer[survivor].g_sWeaponPrimary[0] != '\0')
	{
		vCheatCommand(survivor, "give", g_esPlayer[survivor].g_sWeaponPrimary);

		iSlot = GetPlayerWeaponSlot(survivor, 0);
		if (iSlot > MaxClients)
		{
			SetEntProp(iSlot, Prop_Send, "m_iClip1", g_esPlayer[survivor].g_iWeaponInfo[0]);
			SetEntProp(survivor, Prop_Send, "m_iAmmo", g_esPlayer[survivor].g_iWeaponInfo[1], .element = iGetWeaponOffset(iSlot));

			if (g_bSecondGame)
			{
				if (g_esPlayer[survivor].g_iWeaponInfo[2] > 0)
				{
					SetEntProp(iSlot, Prop_Send, "m_upgradeBitVec", g_esPlayer[survivor].g_iWeaponInfo[2]);
				}

				if (g_esPlayer[survivor].g_iWeaponInfo[3] > 0)
				{
					SetEntProp(iSlot, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded", g_esPlayer[survivor].g_iWeaponInfo[3]);
				}
			}
		}
	}

	if (g_esPlayer[survivor].g_sWeaponSecondary[0] != '\0')
	{
		switch (g_esPlayer[survivor].g_bDualWielding)
		{
			case true:
			{
				vCheatCommand(survivor, "give", "weapon_pistol");
				vCheatCommand(survivor, "give", "weapon_pistol");
			}
			case false: vCheatCommand(survivor, "give", g_esPlayer[survivor].g_sWeaponSecondary);
		}

		iSlot = GetPlayerWeaponSlot(survivor, 1);
		if (iSlot > MaxClients && g_esPlayer[survivor].g_iWeaponInfo2 != -1)
		{
			SetEntProp(iSlot, Prop_Send, "m_iClip1", g_esPlayer[survivor].g_iWeaponInfo2);
		}
	}

	if (g_esPlayer[survivor].g_sWeaponThrowable[0] != '\0')
	{
		vCheatCommand(survivor, "give", g_esPlayer[survivor].g_sWeaponThrowable);
	}

	if (g_esPlayer[survivor].g_sWeaponMedkit[0] != '\0')
	{
		vCheatCommand(survivor, "give", g_esPlayer[survivor].g_sWeaponMedkit);
	}

	if (g_esPlayer[survivor].g_sWeaponPills[0] != '\0')
	{
		vCheatCommand(survivor, "give", g_esPlayer[survivor].g_sWeaponPills);
	}

	for (int iPos = 0; iPos < (sizeof esPlayer::g_iWeaponInfo); iPos++)
	{
		g_esPlayer[survivor].g_iWeaponInfo[iPos] = 0;
	}

	g_esPlayer[survivor].g_iWeaponInfo2 = -1;
	g_esPlayer[survivor].g_sWeaponPrimary[0] = '\0';
	g_esPlayer[survivor].g_sWeaponSecondary[0] = '\0';
	g_esPlayer[survivor].g_sWeaponThrowable[0] = '\0';
	g_esPlayer[survivor].g_sWeaponMedkit[0] = '\0';
	g_esPlayer[survivor].g_sWeaponPills[0] = '\0';
}

void vRefillGunAmmo(int survivor, bool all = false, bool reset = false, bool override = false)
{
	int iSetting = (bIsDeveloper(survivor, 7) && g_esDeveloper[survivor].g_iDevInfiniteAmmo > g_esPlayer[survivor].g_iInfiniteAmmo) ? g_esDeveloper[survivor].g_iDevInfiniteAmmo : g_esPlayer[survivor].g_iInfiniteAmmo;
	iSetting = all ? iSetting : 0;

	int iSlot = 0;
	if (!all || (iSetting > 0 && (iSetting & MT_INFAMMO_PRIMARY)))
	{
		iSlot = GetPlayerWeaponSlot(survivor, 0);
		if (iSlot > MaxClients)
		{
			int iMaxClip = reset ? iGetMaxAmmo(survivor, 0, iSlot, false, true) : g_esPlayer[survivor].g_iMaxClip[0];
			if (override || !reset || (reset && GetEntProp(iSlot, Prop_Send, "m_iClip1") >= iMaxClip))
			{
				SetEntProp(iSlot, Prop_Send, "m_iClip1", iMaxClip);

				if (g_bSecondGame)
				{
					int iUpgrades = GetEntProp(iSlot, Prop_Send, "m_upgradeBitVec");
					if ((iUpgrades & MT_UPGRADE_INCENDIARY) || (iUpgrades & MT_UPGRADE_EXPLOSIVE))
					{
						SetEntProp(iSlot, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded", iMaxClip);
					}
				}
			}

			vRefillGunMagazine(survivor, iSlot, reset, override);
		}
	}

	if (!all || (iSetting > 0 && (iSetting & MT_INFAMMO_SECONDARY)))
	{
		iSlot = GetPlayerWeaponSlot(survivor, 1);
		if (iSlot > MaxClients)
		{
			char sWeapon[32];
			GetEntityClassname(iSlot, sWeapon, sizeof sWeapon);
			if ((!strncmp(sWeapon[7], "pistol", 6) || StrEqual(sWeapon[7], "chainsaw")) && (override || !reset || (reset && GetEntProp(iSlot, Prop_Send, "m_iClip1") >= g_esPlayer[survivor].g_iMaxClip[1])))
			{
				SetEntProp(iSlot, Prop_Send, "m_iClip1", g_esPlayer[survivor].g_iMaxClip[1]);
			}
		}
	}

	if (all && iSetting > 0)
	{
		iSlot = GetPlayerWeaponSlot(survivor, 2);
		if (!bIsValidEntity(iSlot) && (iSetting & MT_INFAMMO_THROWABLE))
		{
			vCheatCommand(survivor, "give", g_esPlayer[survivor].g_sStoredThrowable);
		}

		iSlot = GetPlayerWeaponSlot(survivor, 3);
		if (!bIsValidEntity(iSlot) && (iSetting & MT_INFAMMO_MEDKIT))
		{
			vCheatCommand(survivor, "give", g_esPlayer[survivor].g_sStoredMedkit);
		}

		iSlot = GetPlayerWeaponSlot(survivor, 4);
		if (!bIsValidEntity(iSlot) && (iSetting & MT_INFAMMO_PILLS))
		{
			vCheatCommand(survivor, "give", g_esPlayer[survivor].g_sStoredPills);
		}
	}
}

void vRefillGunMagazine(int survivor, int weapon, bool reset, bool override)
{
	int iAmmoOffset = iGetWeaponOffset(weapon), iNewAmmo = 0;

	switch (override || !reset)
	{
		case true: iNewAmmo = iGetMaxAmmo(survivor, 0, weapon, true, reset);
		case false:
		{
			int iMaxAmmo = iGetMaxAmmo(survivor, 0, weapon, true, reset);
			if (GetEntProp(survivor, Prop_Send, "m_iAmmo", .element = iAmmoOffset) > iMaxAmmo)
			{
				iNewAmmo = iMaxAmmo;
			}
		}
	}

	if (iNewAmmo > 0)
	{
		SetEntProp(survivor, Prop_Send, "m_iAmmo", iNewAmmo, .element = iAmmoOffset);
	}
}

void vRefillSurvivorHealth(int survivor)
{
	if (bIsSurvivorDisabled(survivor) || GetEntProp(survivor, Prop_Data, "m_iHealth") < GetEntProp(survivor, Prop_Data, "m_iMaxHealth"))
	{
		int iMode = GetEntProp(survivor, Prop_Data, "m_takedamage", 1);
		if (iMode != 2)
		{
			SetEntProp(survivor, Prop_Data, "m_takedamage", 2, 1);
			vCheatCommand(survivor, "give", "health");
			SetEntProp(survivor, Prop_Data, "m_takedamage", iMode, 1);
		}
		else
		{
			vCheatCommand(survivor, "give", "health");
		}

		g_esPlayer[survivor].g_bLastLife = false;
		g_esPlayer[survivor].g_iReviveCount = 0;
	}
}

void vRemoveSurvivorEffects(int survivor, bool body = false)
{
	int iEffect = -1;
	for (int iPos = 0; iPos < (sizeof esPlayer::g_iEffect); iPos++)
	{
		iEffect = g_esPlayer[survivor].g_iEffect[iPos];
		if (bIsValidEntRef(iEffect))
		{
			RemoveEntity(iEffect);
		}

		g_esPlayer[survivor].g_iEffect[iPos] = INVALID_ENT_REFERENCE;
	}

	if (body || bIsValidClient(survivor))
	{
		vRemovePlayerGlow(survivor);
		vRemoveSurvivorLight(survivor);
		SetEntityRenderMode(survivor, RENDER_NORMAL);
		SetEntityRenderColor(survivor, 255, 255, 255, 255);
	}

	SDKUnhook(survivor, SDKHook_PostThinkPost, OnTankPostThinkPost);
}

void vRemoveSurvivorLight(int survivor)
{
	if (bIsValidEntRef(g_esPlayer[survivor].g_iFlashlight))
	{
		int iProp = EntRefToEntIndex(g_esPlayer[survivor].g_iFlashlight);
		if (bIsValidEntity(iProp))
		{
			RemoveEntity(iProp);
		}

		g_esPlayer[survivor].g_iFlashlight = INVALID_ENT_REFERENCE;
	}
}

void vResetSurvivorStats(int survivor, bool all)
{
	g_esDeveloper[survivor].g_bDevVisual = false;
	g_esPlayer[survivor].g_bFallDamage = false;
	g_esPlayer[survivor].g_bFalling = false;
	g_esPlayer[survivor].g_bFallTracked = false;
	g_esPlayer[survivor].g_bFatalFalling = false;
	g_esPlayer[survivor].g_bRainbowColor = false;
	g_esPlayer[survivor].g_bReleasedJump = false;
	g_esPlayer[survivor].g_bVomited = false;
	g_esPlayer[survivor].g_sLoopingVoiceline[0] = '\0';
	g_esPlayer[survivor].g_flActionDuration = 0.0;
	g_esPlayer[survivor].g_flAttackBoost = 0.0;
	g_esPlayer[survivor].g_flDamageBoost = 0.0;
	g_esPlayer[survivor].g_flDamageResistance = 0.0;
	g_esPlayer[survivor].g_flHealPercent = 0.0;
	g_esPlayer[survivor].g_flJumpHeight = 0.0;
	g_esPlayer[survivor].g_flLastJumpTime = 0.0;
	g_esPlayer[survivor].g_flLastPushTime = 0.0;
	g_esPlayer[survivor].g_flPipeBombDuration = 0.0;
	g_esPlayer[survivor].g_flPreFallZ = 0.0;
	g_esPlayer[survivor].g_flShoveDamage = 0.0;
	g_esPlayer[survivor].g_flShoveRate = 0.0;
	g_esPlayer[survivor].g_flSpeedBoost = 0.0;
	g_esPlayer[survivor].g_iAmmoBoost = 0;
	g_esPlayer[survivor].g_iAmmoRegen = 0;
	g_esPlayer[survivor].g_iBunnyHop = 0;
	g_esPlayer[survivor].g_iBurstDoors = 0;
	g_esPlayer[survivor].g_iCleanKills = 0;
	g_esPlayer[survivor].g_iFallPasses = 0;
	g_esPlayer[survivor].g_iFriendlyFire = 0;
	g_esPlayer[survivor].g_iHealthRegen = 0;
	g_esPlayer[survivor].g_iHollowpointAmmo = 0;
	g_esPlayer[survivor].g_iInextinguishableFire = 0;
	g_esPlayer[survivor].g_iInfiniteAmmo = 0;
	g_esPlayer[survivor].g_iLadderActions = 0;
	g_esPlayer[survivor].g_iLifeLeech = 0;
	g_esPlayer[survivor].g_iMeleeRange = 0;
	g_esPlayer[survivor].g_iMidairDashesLimit = 0;
	g_esPlayer[survivor].g_iNotify = 0;
	g_esPlayer[survivor].g_iPrefsAccess = 0;
	g_esPlayer[survivor].g_iParticleEffect = 0;
	g_esPlayer[survivor].g_iRecoilDampener = 0;
	g_esPlayer[survivor].g_iReviveHealth = 0;
	g_esPlayer[survivor].g_iRewardTypes = 0;
	g_esPlayer[survivor].g_iShovePenalty = 0;
	g_esPlayer[survivor].g_iSledgehammerRounds = 0;
	g_esPlayer[survivor].g_iSpecialAmmo = 0;
	g_esPlayer[survivor].g_iThorns = 0;
	g_esPlayer[survivor].g_iVoicePitch = 0;
	g_esPlayer[survivor].g_sBodyColor[0] = '\0';
	g_esPlayer[survivor].g_sLightColor[0] = '\0';
	g_esPlayer[survivor].g_sOutlineColor[0] = '\0';
	g_esPlayer[survivor].g_sScreenColor[0] = '\0';

	if (all)
	{
		g_esPlayer[survivor].g_bSetup = false;
	}

	for (int iPos = 0; iPos < (sizeof esPlayer::g_flRewardTime); iPos++)
	{
		g_esPlayer[survivor].g_flRewardTime[iPos] = -1.0;
		g_esPlayer[survivor].g_iRewardStack[iPos] = 0;

		if (iPos < (sizeof esPlayer::g_flVisualTime))
		{
			g_esPlayer[survivor].g_flVisualTime[iPos] = -1.0;
		}

		if (iPos < (sizeof esPlayer::g_iScreenColorVisual))
		{
			g_esPlayer[survivor].g_iScreenColorVisual[iPos] = -1;
		}
	}
}

void vResetSurvivorStats2(int survivor)
{
	if (g_esPlayer[survivor].g_iRewardTypes & MT_REWARD_REFILL)
	{
		g_esPlayer[survivor].g_iRewardTypes &= ~MT_REWARD_REFILL;
	}

	if (g_esPlayer[survivor].g_iRewardTypes & MT_REWARD_ITEM)
	{
		g_esPlayer[survivor].g_iRewardTypes &= ~MT_REWARD_ITEM;
	}

	if (g_esPlayer[survivor].g_iRewardTypes & MT_REWARD_RESPAWN)
	{
		g_esPlayer[survivor].g_iRewardTypes &= ~MT_REWARD_RESPAWN;
	}
}

void vRespawnSurvivor(int survivor)
{
	static int iIndex = -1;
	if (iIndex == -1)
	{
		iIndex = iGetPatchIndex("MTPatch_RespawnStats");
	}

	if (iIndex != -1)
	{
		vInstallPatch(iIndex);
	}

	if (g_esGeneral.g_hSDKRoundRespawn != null)
	{
		SDKCall(g_esGeneral.g_hSDKRoundRespawn, survivor);
	}

	if (iIndex != -1)
	{
		vRemovePatch(iIndex);
	}
}

void vReviveSurvivor(int survivor)
{
	if (!bIsSurvivorDisabled(survivor))
	{
		return;
	}

	if (g_esGeneral.g_hSDKRevive != null)
	{
		SDKCall(g_esGeneral.g_hSDKRevive, survivor);
	}
}

void vSaveCaughtSurvivor(int survivor, int special = 0)
{
	int iSpecial = special;
	iSpecial = (iSpecial <= 0) ? GetEntPropEnt(survivor, Prop_Send, "m_pounceAttacker") : iSpecial;
	iSpecial = (iSpecial <= 0) ? GetEntPropEnt(survivor, Prop_Send, "m_tongueOwner") : iSpecial;
	if (g_bSecondGame)
	{
		iSpecial = (iSpecial <= 0) ? GetEntPropEnt(survivor, Prop_Send, "m_pummelAttacker") : iSpecial;
		iSpecial = (iSpecial <= 0) ? GetEntPropEnt(survivor, Prop_Send, "m_carryAttacker") : iSpecial;
		iSpecial = (iSpecial <= 0) ? GetEntPropEnt(survivor, Prop_Send, "m_jockeyAttacker") : iSpecial;
	}

	if (bIsSpecialInfected(iSpecial))
	{
		SDKHooks_TakeDamage(iSpecial, survivor, survivor, float(GetEntProp(iSpecial, Prop_Data, "m_iHealth")));
	}
}

void vSaveSurvivorWeapons(int survivor)
{
	char sWeapon[32];
	g_esPlayer[survivor].g_iWeaponInfo2 = -1;
	int iSlot = GetPlayerWeaponSlot(survivor, 0);
	if (iSlot > MaxClients)
	{
		GetEntityClassname(iSlot, sWeapon, sizeof sWeapon);
		strcopy(g_esPlayer[survivor].g_sWeaponPrimary, sizeof esPlayer::g_sWeaponPrimary, sWeapon);

		g_esPlayer[survivor].g_iWeaponInfo[0] = GetEntProp(iSlot, Prop_Send, "m_iClip1");
		g_esPlayer[survivor].g_iWeaponInfo[1] = GetEntProp(survivor, Prop_Send, "m_iAmmo", .element = iGetWeaponOffset(iSlot));

		if (g_bSecondGame)
		{
			g_esPlayer[survivor].g_iWeaponInfo[2] = GetEntProp(iSlot, Prop_Send, "m_upgradeBitVec");
			g_esPlayer[survivor].g_iWeaponInfo[3] = GetEntProp(iSlot, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded");
		}
	}

	iSlot = 0;
	if (g_bSecondGame)
	{
		if (bIsSurvivorDisabled(survivor) && g_esGeneral.g_iMeleeOffset != -1)
		{
			int iMelee = GetEntDataEnt2(survivor, g_esGeneral.g_iMeleeOffset);

			switch (bIsValidEntity(iMelee))
			{
				case true: iSlot = iMelee;
				case false: iSlot = GetPlayerWeaponSlot(survivor, 1);
			}
		}
		else
		{
			iSlot = GetPlayerWeaponSlot(survivor, 1);
		}
	}
	else
	{
		iSlot = GetPlayerWeaponSlot(survivor, 1);
	}

	if (iSlot > MaxClients)
	{
		GetEntityClassname(iSlot, sWeapon, sizeof sWeapon);
		if (StrEqual(sWeapon[7], "melee"))
		{
			GetEntPropString(iSlot, Prop_Data, "m_strMapSetScriptName", sWeapon, sizeof sWeapon);
		}

		strcopy(g_esPlayer[survivor].g_sWeaponSecondary, sizeof esPlayer::g_sWeaponSecondary, sWeapon);
		if (!strncmp(sWeapon[7], "pistol", 6) || StrEqual(sWeapon[7], "chainsaw"))
		{
			g_esPlayer[survivor].g_iWeaponInfo2 = GetEntProp(iSlot, Prop_Send, "m_iClip1");
		}

		g_esPlayer[survivor].g_bDualWielding = !strncmp(sWeapon[7], "pistol", 6) && GetEntProp(iSlot, Prop_Send, "m_isDualWielding") > 0;
	}

	iSlot = GetPlayerWeaponSlot(survivor, 2);
	if (iSlot > MaxClients)
	{
		GetEntityClassname(iSlot, sWeapon, sizeof sWeapon);
		strcopy(g_esPlayer[survivor].g_sWeaponThrowable, sizeof esPlayer::g_sWeaponThrowable, sWeapon);
	}

	iSlot = GetPlayerWeaponSlot(survivor, 3);
	if (iSlot > MaxClients)
	{
		GetEntityClassname(iSlot, sWeapon, sizeof sWeapon);
		strcopy(g_esPlayer[survivor].g_sWeaponMedkit, sizeof esPlayer::g_sWeaponMedkit, sWeapon);
	}

	iSlot = GetPlayerWeaponSlot(survivor, 4);
	if (iSlot > MaxClients)
	{
		GetEntityClassname(iSlot, sWeapon, sizeof sWeapon);
		strcopy(g_esPlayer[survivor].g_sWeaponPills, sizeof esPlayer::g_sWeaponPills, sWeapon);
	}
}

void vSetSurvivorColor(int survivor, const char[] colors, bool apply = true, const char[] delimiter = ";", bool save = false)
{
	if (!save && !bIsDeveloper(survivor, 0))
	{
		return;
	}

	char sColor[64];
	strcopy(sColor, sizeof sColor, colors);
	if (StrEqual(sColor, "rainbow", false))
	{
		if (!g_esPlayer[survivor].g_bRainbowColor)
		{
			g_esPlayer[survivor].g_bRainbowColor = SDKHookEx(survivor, SDKHook_PreThinkPost, OnRainbowPreThinkPost);
		}

		return;
	}

	char sValue[4][4];
	vGetConfigColors(sColor, sizeof sColor, colors);
	ExplodeString(sColor, delimiter, sValue, sizeof sValue, sizeof sValue[]);

	int iColor[4];
	for (int iPos = 0; iPos < (sizeof sValue); iPos++)
	{
		if (sValue[iPos][0] != '\0')
		{
			iColor[iPos] = iGetRandomColor(StringToInt(sValue[iPos]));
		}
	}

	switch (apply)
	{
		case true:
		{
			switch (iColor[3] < 255)
			{
				case true: SetEntityRenderMode(survivor, RENDER_TRANSCOLOR);
				case false: SetEntityRenderMode(survivor, RENDER_NORMAL);
			}

			SetEntityRenderColor(survivor, iColor[0], iColor[1], iColor[2], iColor[3]);
		}
		case false:
		{
			SetEntityRenderMode(survivor, RENDER_NORMAL);
			SetEntityRenderColor(survivor, 255, 255, 255, 255);
		}
	}
}

void vSetSurvivorEffects(int survivor, int effects)
{
	if (effects & MT_ROCK_BLOOD)
	{
		vAttachParticle(survivor, PARTICLE_BLOOD, 0.75, 30.0);
	}

	if (effects & MT_ROCK_ELECTRICITY)
	{
		switch (bIsValidClient(survivor, MT_CHECK_FAKECLIENT))
		{
			case true: vAttachParticle(survivor, PARTICLE_ELECTRICITY, 0.75, 30.0);
			case false:
			{
				for (int iCount = 1; iCount < 4; iCount++)
				{
					vAttachParticle(survivor, PARTICLE_ELECTRICITY, 0.75, (1.0 * float(iCount * 15)));
				}
			}
		}
	}

	if (effects & MT_ROCK_FIRE)
	{
		vAttachParticle(survivor, PARTICLE_FIRE, 0.75);
	}

	if (effects & MT_ROCK_SPIT)
	{
		switch (g_bSecondGame)
		{
			case true: vAttachParticle(survivor, PARTICLE_SPIT, 0.75, 30.0);
			case false: vAttachParticle(survivor, PARTICLE_BLOOD, 0.75, 30.0);
		}
	}
}

void vSetSurvivorGlow(int survivor, int red, int green, int blue)
{
	if (!g_bSecondGame)
	{
		return;
	}

	SetEntProp(survivor, Prop_Send, "m_glowColorOverride", iGetRGBColor(red, green, blue));
	SetEntProp(survivor, Prop_Send, "m_bFlashing", 0);
	SetEntProp(survivor, Prop_Send, "m_nGlowRangeMin", 0);
	SetEntProp(survivor, Prop_Send, "m_nGlowRange", 99999);
	SetEntProp(survivor, Prop_Send, "m_iGlowType", 3);
}

void vSetSurvivorFlashlight(int survivor, int colors[4])
{
	if (g_esPlayer[survivor].g_iFlashlight == 0 || g_esPlayer[survivor].g_iFlashlight == INVALID_ENT_REFERENCE)
	{
		float flOrigin[3], flAngles[3];
		GetEntPropVector(survivor, Prop_Data, "m_vecOrigin", flOrigin);
		GetEntPropVector(survivor, Prop_Data, "m_angRotation", flAngles);
		vFlashlightProp(survivor, flOrigin, flAngles, colors);
	}
	else if (bIsValidEntRef(g_esPlayer[survivor].g_iFlashlight))
	{
		int iProp = EntRefToEntIndex(g_esPlayer[survivor].g_iFlashlight);
		if (bIsValidEntity(iProp))
		{
			char sColor[16];
			FormatEx(sColor, sizeof sColor, "%i %i %i %i", iGetRandomColor(colors[0]), iGetRandomColor(colors[1]), iGetRandomColor(colors[2]), iGetRandomColor(colors[3]));
			DispatchKeyValue(g_esPlayer[survivor].g_iFlashlight, "_light", sColor);
		}
	}
}

void vSetSurvivorLight(int survivor, const char[] colors, bool apply = true, const char[] delimiter = ";", bool save = false)
{
	if (!save && !bIsDeveloper(survivor, 0))
	{
		return;
	}

	char sColor[64];
	strcopy(sColor, sizeof sColor, colors);
	if (StrEqual(sColor, "rainbow", false))
	{
		if (!g_esPlayer[survivor].g_bRainbowColor)
		{
			g_esPlayer[survivor].g_bRainbowColor = SDKHookEx(survivor, SDKHook_PreThinkPost, OnRainbowPreThinkPost);
		}

		return;
	}

	char sValue[4][4];
	vGetConfigColors(sColor, sizeof sColor, colors);
	ExplodeString(sColor, delimiter, sValue, sizeof sValue, sizeof sValue[]);

	int iColor[4];
	for (int iPos = 0; iPos < (sizeof sValue); iPos++)
	{
		if (sValue[iPos][0] != '\0')
		{
			iColor[iPos] = iGetRandomColor(StringToInt(sValue[iPos]));
		}
	}

	switch (apply)
	{
		case true: vSetSurvivorFlashlight(survivor, iColor);
		case false: vRemoveSurvivorLight(survivor);
	}
}

void vSetSurvivorOutline(int survivor, const char[] colors, bool apply = true, const char[] delimiter = ";", bool save = false)
{
	if (!g_bSecondGame || (!save && !bIsDeveloper(survivor, 0)))
	{
		return;
	}

	char sColor[64];
	strcopy(sColor, sizeof sColor, colors);
	if (StrEqual(sColor, "rainbow", false))
	{
		if (!g_esPlayer[survivor].g_bRainbowColor)
		{
			g_esPlayer[survivor].g_bRainbowColor = SDKHookEx(survivor, SDKHook_PreThinkPost, OnRainbowPreThinkPost);
		}

		return;
	}

	char sValue[3][4];
	vGetConfigColors(sColor, sizeof sColor, colors);
	ExplodeString(sColor, delimiter, sValue, sizeof sValue, sizeof sValue[]);

	int iColor[3];
	for (int iPos = 0; iPos < (sizeof sValue); iPos++)
	{
		if (sValue[iPos][0] != '\0')
		{
			iColor[iPos] = iGetRandomColor(StringToInt(sValue[iPos]));
		}
	}

	switch (apply)
	{
		case true: vSetSurvivorGlow(survivor, iColor[0], iColor[1], iColor[2]);
		case false: vRemovePlayerGlow(survivor);
	}
}

void vSetSurvivorParticle(int survivor)
{
	if (!g_esDeveloper[survivor].g_bDevVisual)
	{
		g_esDeveloper[survivor].g_bDevVisual = true;

		CreateTimer(0.75, tTimerDevParticle, GetClientUserId(survivor), TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
	}
}

void vSetSurvivorScreen(int survivor, const char[] colors, const char[] delimiter = ";")
{
	char sColor[64];
	strcopy(sColor, sizeof sColor, colors);
	if (StrEqual(sColor, "rainbow", false))
	{
		if (!g_esPlayer[survivor].g_bRainbowColor)
		{
			g_esPlayer[survivor].g_bRainbowColor = SDKHookEx(survivor, SDKHook_PreThinkPost, OnRainbowPreThinkPost);
		}

		return;
	}

	char sValue[4][4];
	ExplodeString(sColor, delimiter, sValue, sizeof sValue, sizeof sValue[]);
	for (int iPos = 0; iPos < (sizeof sValue); iPos++)
	{
		if (sValue[iPos][0] != '\0')
		{
			g_esPlayer[survivor].g_iScreenColorVisual[iPos] = iGetRandomColor(StringToInt(sValue[iPos]));
		}
	}
}

void vSetSurvivorWeaponSkin(int developer)
{
	int iActiveWeapon = GetEntPropEnt(developer, Prop_Send, "m_hActiveWeapon");
	if (bIsValidEntity(iActiveWeapon))
	{
		int iSkin = iClamp(g_esDeveloper[developer].g_iDevWeaponSkin, -1, iGetMaxWeaponSkins(developer));
		if (iSkin != -1 && iSkin != GetEntProp(iActiveWeapon, Prop_Send, "m_nSkin"))
		{
			SetEntProp(iActiveWeapon, Prop_Send, "m_nSkin", iSkin);

			int iViewWeapon = GetEntPropEnt(developer, Prop_Send, "m_hViewModel");
			if (bIsValidEntity(iViewWeapon))
			{
				SetEntProp(iViewWeapon, Prop_Send, "m_nSkin", iSkin);
			}
		}
	}
}

void vSetupAdmin(int admin, const char[] keyword, const char[] value)
{
	if (StrContains(keyword, "effect", false) != -1 || StrContains(keyword, "particle", false) != -1)
	{
		g_esDeveloper[admin].g_iDevParticle = iClamp(StringToInt(value), 0, 15);

		switch (StringToInt(value) == 0)
		{
			case true: g_esDeveloper[admin].g_bDevVisual = false;
			case false: vSetSurvivorParticle(admin);
		}
#if defined _clientprefs_included
		g_esGeneral.g_ckMTAdmin[1].Set(admin, value);
#endif
	}
	else if (StrContains(keyword, "glow", false) != -1 || StrContains(keyword, "outline", false) != -1)
	{
		switch (StrEqual(value, "0"))
		{
			case true:
			{
				g_esDeveloper[admin].g_sDevGlowOutline[0] = '\0';

				vToggleSurvivorEffects(admin, true, 6);
			}
			case false:
			{
				strcopy(g_esDeveloper[admin].g_sDevGlowOutline, sizeof esDeveloper::g_sDevGlowOutline, value);
				vSetSurvivorOutline(admin, g_esDeveloper[admin].g_sDevGlowOutline, .delimiter = ",");
			}
		}
#if defined _clientprefs_included
		g_esGeneral.g_ckMTAdmin[2].Set(admin, value);
#endif
	}
	else if (StrContains(keyword, "light", false) != -1 || StrContains(keyword, "flash", false) != -1)
	{
		switch (StrEqual(value, "0"))
		{
			case true:
			{
				g_esDeveloper[admin].g_sDevFlashlight[0] = '\0';

				vToggleSurvivorEffects(admin, true, 4);
			}
			case false:
			{
				strcopy(g_esDeveloper[admin].g_sDevFlashlight, sizeof esDeveloper::g_sDevFlashlight, value);
				vSetSurvivorLight(admin, g_esDeveloper[admin].g_sDevFlashlight, .delimiter = ",");
			}
		}
#if defined _clientprefs_included
		g_esGeneral.g_ckMTAdmin[3].Set(admin, value);
#endif
	}
	else if (StrContains(keyword, "skin", false) != -1 || StrContains(keyword, "color", false) != -1)
	{
		switch (StrEqual(value, "0"))
		{
			case true:
			{
				g_esDeveloper[admin].g_sDevSkinColor[0] = '\0';

				vToggleSurvivorEffects(admin, true, 5);
			}
			case false:
			{
				strcopy(g_esDeveloper[admin].g_sDevSkinColor, sizeof esDeveloper::g_sDevSkinColor, value);
				vSetSurvivorColor(admin, g_esDeveloper[admin].g_sDevSkinColor, .delimiter = ",");
			}
		}
#if defined _clientprefs_included
		g_esGeneral.g_ckMTAdmin[4].Set(admin, value);
#endif
	}
	else if (StrContains(keyword, "voice", false) != -1 || StrContains(keyword, "pitch", false) != -1)
	{
		g_esDeveloper[admin].g_iDevVoicePitch = iClamp(StringToInt(value), 0, 255);
#if defined _clientprefs_included
		g_esGeneral.g_ckMTAdmin[5].Set(admin, value);
#endif
	}

	vAdminPanel(admin);
}

void vSetupDeveloper(int developer, bool setup = true, bool usual = false)
{
	if (setup)
	{
		if (bIsSurvivor(developer))
		{
			vSetupLoadout(developer, usual);
			vGiveGunSpecialAmmo(developer);
			vCheckGunClipSizes(developer);

			if (bIsDeveloper(developer, 0))
			{
				vSetSurvivorLight(developer, g_esDeveloper[developer].g_sDevFlashlight, .delimiter = ",");
				vSetSurvivorOutline(developer, g_esDeveloper[developer].g_sDevGlowOutline, .delimiter = ",");
				vSetSurvivorColor(developer, g_esDeveloper[developer].g_sDevSkinColor, .delimiter = ",");
				vSetSurvivorParticle(developer);
			}
			else if (g_esDeveloper[developer].g_bDevVisual)
			{
				g_esDeveloper[developer].g_bDevVisual = false;

				vToggleSurvivorEffects(developer);
			}

			switch (bIsDeveloper(developer, 4) || ((g_esPlayer[developer].g_iRewardTypes & MT_REWARD_DAMAGEBOOST) && g_esPlayer[developer].g_iRecoilDampener == 1))
			{
				case true: vToggleWeaponVerticalPunch(developer, true);
				case false: vToggleWeaponVerticalPunch(developer, false);
			}

			switch (bIsDeveloper(developer, 5) || (g_esPlayer[developer].g_iRewardTypes & MT_REWARD_SPEEDBOOST))
			{
				case true:
				{
					vReviveSurvivor(developer);
					vSaveCaughtSurvivor(developer);
					vSetAdrenalineTime(developer, 99999.0);
					SDKHook(developer, SDKHook_PreThinkPost, OnSpeedPreThinkPost);
				}
				case false:
				{
					vSetAdrenalineTime(developer, 0.0);
					SDKUnhook(developer, SDKHook_PreThinkPost, OnSpeedPreThinkPost);
					SetEntPropFloat(developer, Prop_Send, "m_flLaggedMovementValue", 1.0);
				}
			}

			switch (bIsDeveloper(developer, 6) || (g_esPlayer[developer].g_iRewardTypes & MT_REWARD_ATTACKBOOST))
			{
				case true: SDKHook(developer, SDKHook_PostThinkPost, OnSurvivorPostThinkPost);
				case false: SDKUnhook(developer, SDKHook_PostThinkPost, OnSurvivorPostThinkPost);
			}

			switch (bIsDeveloper(developer, 11) || (g_esPlayer[developer].g_iRewardTypes & MT_REWARD_GODMODE))
			{
				case true:
				{
					if (g_esPlayer[developer].g_bVomited)
					{
						vUnvomitPlayer(developer);
					}

					vSaveCaughtSurvivor(developer);
					SetEntProp(developer, Prop_Data, "m_takedamage", 0, 1);
				}
				case false: SetEntProp(developer, Prop_Data, "m_takedamage", 2, 1);
			}
		}
	}
	else if (bIsValidClient(developer))
	{
		vToggleWeaponVerticalPunch(developer, false);
		SDKUnhook(developer, SDKHook_PreThinkPost, OnSpeedPreThinkPost);
		SDKUnhook(developer, SDKHook_PostThinkPost, OnSurvivorPostThinkPost);

		if (bIsValidClient(developer, MT_CHECK_ALIVE))
		{
			if (g_esDeveloper[developer].g_bDevVisual)
			{
				vToggleSurvivorEffects(developer);
			}

			if (!(g_esPlayer[developer].g_iRewardTypes & MT_REWARD_SPEEDBOOST))
			{
				vSetAdrenalineTime(developer, 0.0);
				SetEntPropFloat(developer, Prop_Send, "m_flLaggedMovementValue", 1.0);
			}

			vCheckGunClipSizes(developer);

			if (!(g_esPlayer[developer].g_iRewardTypes & MT_REWARD_AMMO))
			{
				vRefillGunAmmo(developer, .reset = true);
			}

			if (!(g_esPlayer[developer].g_iRewardTypes & MT_REWARD_GODMODE))
			{
				SetEntProp(developer, Prop_Data, "m_takedamage", 2, 1);
			}
		}

		g_esDeveloper[developer].g_bDevVisual = false;
	}
}

void vSetupGuest(int guest, const char[] keyword, const char[] value)
{
	bool bPanel = false;
	if (StrContains(keyword, "access", false) != -1)
	{
		bPanel = true;
		g_esDeveloper[guest].g_iDevAccess = iClamp(StringToInt(value), 0, MT_DEV_MAXLEVEL);

		vSetupDeveloper(guest, (g_esDeveloper[guest].g_iDevAccess > 0), true);
	}
	else if (StrContains(keyword, "action", false) != -1 || StrContains(keyword, "actdur", false) != -1)
	{
		bPanel = true;
		g_esDeveloper[guest].g_flDevActionDuration = flClamp(StringToFloat(value), 0.0, 99999.0);
	}
	else if (StrContains(keyword, "ammoregen", false) != -1 || StrContains(keyword, "regenammo", false) != -1)
	{
		bPanel = true;
		g_esDeveloper[guest].g_iDevAmmoRegen = iClamp(StringToInt(value), 0, 99999);
	}
	else if (StrContains(keyword, "attack", false) != -1)
	{
		bPanel = true;
		g_esDeveloper[guest].g_flDevAttackBoost = flClamp(StringToFloat(value), 0.0, 99999.0);
	}
	else if (StrContains(keyword, "dmgboost", false) != -1 || StrContains(keyword, "damageboost", false) != -1)
	{
		bPanel = true;
		g_esDeveloper[guest].g_flDevDamageBoost = flClamp(StringToFloat(value), 0.0, 99999.0);
	}
	else if (StrContains(keyword, "dmgres", false) != -1 || StrContains(keyword, "damageres", false) != -1)
	{
		bPanel = true;
		g_esDeveloper[guest].g_flDevDamageResistance = flClamp(StringToFloat(value), 0.0, 0.99);
	}
	else if (StrContains(keyword, "effect", false) != -1 || StrContains(keyword, "particle", false) != -1)
	{
		bPanel = true;
		g_esDeveloper[guest].g_iDevParticle = iClamp(StringToInt(value), 0, 15);
	}
	else if (StrContains(keyword, "fall", false) != -1 || StrContains(keyword, "scream", false) != -1 || StrContains(keyword, "voice", false) != -1)
	{
		bPanel = true;

		strcopy(g_esDeveloper[guest].g_sDevFallVoiceline, sizeof esDeveloper::g_sDevFallVoiceline, value);
	}
	else if (StrContains(keyword, "glow", false) != -1 || StrContains(keyword, "outline", false) != -1)
	{
		bPanel = true;

		strcopy(g_esDeveloper[guest].g_sDevGlowOutline, sizeof esDeveloper::g_sDevGlowOutline, value);
		vSetSurvivorOutline(guest, g_esDeveloper[guest].g_sDevGlowOutline, .delimiter = ",");
	}
	else if (StrContains(keyword, "heal", false) != -1 || StrContains(keyword, "hppercent", false) != -1)
	{
		bPanel = true;
		g_esDeveloper[guest].g_flDevHealPercent = flClamp(StringToFloat(value), 0.0, 100.0);
	}
	else if (StrContains(keyword, "regenhp", false) != -1 || StrContains(keyword, "hpregen", false) != -1)
	{
		bPanel = true;
		g_esDeveloper[guest].g_iDevHealthRegen = iClamp(StringToInt(value), 0, MT_MAXHEALTH);
	}
	else if (StrContains(keyword, "hud", false) != -1)
	{
		delete g_esPlayer[guest].g_hHudTimer;

		g_esPlayer[guest].g_hHudTimer = CreateTimer(1.0, tTimerHudPanel, GetClientUserId(guest), TIMER_REPEAT);
	}
	else if (StrContains(keyword, "infammo", false) != -1 || StrContains(keyword, "infinite", false) != -1)
	{
		bPanel = true;
		g_esDeveloper[guest].g_iDevInfiniteAmmo = iClamp(StringToInt(value), 0, 31);
	}
	else if (StrContains(keyword, "jump", false) != -1 || StrContains(keyword, "height", false) != -1)
	{
		bPanel = true;
		g_esDeveloper[guest].g_flDevJumpHeight = flClamp(StringToFloat(value), 0.0, 99999.0);
	}
	else if (StrContains(keyword, "midair", false) != -1 || StrContains(keyword, "dash", false) != -1)
	{
		bPanel = true;
		g_esDeveloper[guest].g_iDevMidairDashes = iClamp(StringToInt(value), 0, 99999);
	}
	else if (StrContains(keyword, "leech", false) != -1)
	{
		bPanel = true;
		g_esDeveloper[guest].g_iDevLifeLeech = iClamp(StringToInt(value), 0, MT_MAXHEALTH);
	}
	else if (StrContains(keyword, "light", false) != -1 || StrContains(keyword, "flash", false) != -1)
	{
		bPanel = true;

		strcopy(g_esDeveloper[guest].g_sDevFlashlight, sizeof esDeveloper::g_sDevFlashlight, value);
		vSetSurvivorLight(guest, g_esDeveloper[guest].g_sDevFlashlight, .delimiter = ",");
	}
	else if (StrContains(keyword, "loadout", false) != -1 || StrContains(keyword, "weapons", false) != -1)
	{
		bPanel = true;

		strcopy(g_esDeveloper[guest].g_sDevLoadout, sizeof esDeveloper::g_sDevLoadout, value);
		vSetupLoadout(guest);
	}
	else if (StrContains(keyword, "melee", false) != -1 || StrContains(keyword, "range", false) != -1)
	{
		bPanel = true;
		g_esDeveloper[guest].g_iDevMeleeRange = iClamp(StringToInt(value), 0, 99999);
	}
	else if (StrContains(keyword, "pipe", false) != -1 || StrContains(keyword, "bomb", false) != -1 || StrContains(keyword, "pipedur", false) != -1 || StrContains(keyword, "bombdur", false) != -1)
	{
		bPanel = true;
		g_esDeveloper[guest].g_flDevPipeBombDuration = flClamp(StringToFloat(value), 0.0, 99999.0);
	}
	else if (StrContains(keyword, "punch", false) != -1 || StrContains(keyword, "force", false) != -1 || StrContains(keyword, "punchres", false) != -1)
	{
		bPanel = true;
		g_esDeveloper[guest].g_flDevPunchResistance = flClamp(StringToFloat(value), 0.0, 99999.0);
	}
	else if (StrContains(keyword, "revivehp", false) != -1 || StrContains(keyword, "hprevive", false) != -1)
	{
		bPanel = true;
		g_esDeveloper[guest].g_iDevReviveHealth = iClamp(StringToInt(value), 0, MT_MAXHEALTH);
	}
	else if (StrContains(keyword, "rdur", false) != -1 || StrContains(keyword, "rewarddur", false) != -1)
	{
		bPanel = true;
		g_esDeveloper[guest].g_flDevRewardDuration = flClamp(StringToFloat(value), 0.0, 99999.0);
	}
	else if (StrContains(keyword, "rtypes", false) != -1 || StrContains(keyword, "rewardtypes", false) != -1)
	{
		bPanel = true;
		g_esDeveloper[guest].g_iDevRewardTypes = iClamp(StringToInt(value), -1, 2147483647);
	}
	else if (StrContains(keyword, "sdmg", false) != -1 || StrContains(keyword, "shovedmg", false) != -1)
	{
		bPanel = true;
		g_esDeveloper[guest].g_flDevShoveDamage = flClamp(StringToFloat(value), 0.0, 99999.0);
	}
	else if (StrContains(keyword, "srate", false) != -1 || StrContains(keyword, "shoverate", false) != -1)
	{
		bPanel = true;
		g_esDeveloper[guest].g_flDevShoveRate = flClamp(StringToFloat(value), 0.0, 99999.0);
	}
	else if (StrContains(keyword, "survskin", false) != -1 || StrContains(keyword, "color", false) != -1)
	{
		bPanel = true;

		strcopy(g_esDeveloper[guest].g_sDevSkinColor, sizeof esDeveloper::g_sDevSkinColor, value);
		vSetSurvivorColor(guest, g_esDeveloper[guest].g_sDevSkinColor, .delimiter = ",");
	}
	else if (StrContains(keyword, "specammo", false) != -1 || StrContains(keyword, "special", false) != -1)
	{
		bPanel = true;
		g_esDeveloper[guest].g_iDevSpecialAmmo = iClamp(StringToInt(value), 0, 3);

		vGiveGunSpecialAmmo(guest);
	}
	else if (StrContains(keyword, "speed", false) != -1)
	{
		bPanel = true;
		g_esDeveloper[guest].g_flDevSpeedBoost = flClamp(StringToFloat(value), 0.0, 99999.0);

		vSetAdrenalineTime(guest, 99999.0);
	}
	else if (StrContains(keyword, "voice", false) != -1 || StrContains(keyword, "pitch", false) != -1)
	{
		bPanel = true;
		g_esDeveloper[guest].g_iDevVoicePitch = iClamp(StringToInt(value), 0, 255);
	}
	else if (StrContains(keyword, "wepskin", false) != -1 || StrContains(keyword, "skin", false) != -1)
	{
		bPanel = true;
		g_esDeveloper[guest].g_iDevWeaponSkin = iClamp(StringToInt(value), -1, iGetMaxWeaponSkins(guest));

		vSetSurvivorWeaponSkin(guest);
	}
	else if (StrContains(keyword, "config", false) != -1)
	{
		bPanel = !!StringToInt(value);

		switch (IsVoteInProgress())
		{
			case true: MT_PrintToChat(guest, "%s %t", MT_TAG2, "Vote in Progress");
			case false: vPathMenu(guest);
		}
	}
	else if (StrContains(keyword, "list", false) != -1)
	{
		bPanel = !!StringToInt(value);

		vListAbilities(guest);
	}
	else if (StrContains(keyword, "tank", false) != -1)
	{
		bPanel = !!StringToInt(value);

		switch (IsVoteInProgress())
		{
			case true: MT_PrintToChat(guest, "%s %t", MT_TAG2, "Vote in Progress");
			case false: vTankMenu(guest);
		}
	}
	else if (StrContains(keyword, "version", false) != -1)
	{
		bPanel = !!StringToInt(value);

		MT_PrintToChat(guest, "%s %s{yellow} v%s{mint}, by{olive} %s", MT_TAG3, MT_CONFIG_SECTION_MAIN, MT_VERSION, MT_AUTHOR);
	}

	if (bPanel)
	{
		vDeveloperPanel(guest);
	}
}

void vSetupLoadout(int developer, bool usual = true)
{
	if (bIsDeveloper(developer, 2))
	{
		vRemoveWeapons(developer);

		if (usual)
		{
			char sSet[6][64];
			ExplodeString(g_esDeveloper[developer].g_sDevLoadout, ",", sSet, sizeof sSet, sizeof sSet[]);
			vCheatCommand(developer, "give", "health");

			switch (g_bSecondGame && StrContains(sSet[1], "pistol") == -1 && StrContains(sSet[1], "chainsaw") == -1)
			{
				case true:
				{
					if (sSet[1][0] != '\0')
					{
						vGiveSurvivorRandomMeleeWeapon(developer, usual, sSet[1]);
					}
				}
				case false:
				{
					if (sSet[1][0] != '\0')
					{
						vCheatCommand(developer, "give", sSet[1]);
					}

					if (sSet[5][0] != '\0')
					{
						vCheatCommand(developer, "give", sSet[5]);
					}
				}
			}

			for (int iPos = 0; iPos < ((sizeof sSet) - 1); iPos++)
			{
				if (iPos != 1 && sSet[iPos][0] != '\0')
				{
					vCheatCommand(developer, "give", sSet[iPos]);
				}
			}
		}
		else
		{
			if (g_bSecondGame)
			{
				vGiveSurvivorRandomMeleeWeapon(developer, usual);

				switch (MT_GetRandomInt(1, 5))
				{
					case 1: vCheatCommand(developer, "give", "shotgun_spas");
					case 2: vCheatCommand(developer, "give", "autoshotgun");
					case 3: vCheatCommand(developer, "give", "rifle_ak47");
					case 4: vCheatCommand(developer, "give", "rifle");
					case 5: vCheatCommand(developer, "give", "sniper_military");
				}

				switch (MT_GetRandomInt(1, 3))
				{
					case 1: vCheatCommand(developer, "give", "molotov");
					case 2: vCheatCommand(developer, "give", "pipe_bomb");
					case 3: vCheatCommand(developer, "give", "vomitjar");
				}

				switch (MT_GetRandomInt(1, 2))
				{
					case 1: vCheatCommand(developer, "give", "first_aid_kit");
					case 2: vCheatCommand(developer, "give", "defibrillator");
				}

				switch (MT_GetRandomInt(1, 2))
				{
					case 1: vCheatCommand(developer, "give", "pain_pills");
					case 2: vCheatCommand(developer, "give", "adrenaline");
				}
			}
			else
			{
				switch (MT_GetRandomInt(1, 3))
				{
					case 1: vCheatCommand(developer, "give", "autoshotgun");
					case 2: vCheatCommand(developer, "give", "rifle");
					case 3: vCheatCommand(developer, "give", "hunting_rifle");
				}

				switch (MT_GetRandomInt(1, 2))
				{
					case 1: vCheatCommand(developer, "give", "molotov");
					case 2: vCheatCommand(developer, "give", "pipe_bomb");
				}

				vCheatCommand(developer, "give", "pistol");
				vCheatCommand(developer, "give", "pistol");
				vCheatCommand(developer, "give", "first_aid_kit");
				vCheatCommand(developer, "give", "pain_pills");
			}
		}

		vCheckGunClipSizes(developer);
	}
}

void vSetupPerks(int admin, bool setup = true)
{
	if (setup)
	{
		if (bIsSurvivor(admin))
		{
			if (bIsDeveloper(admin, 0))
			{
				if (g_esDeveloper[admin].g_sDevFlashlight[0] != '\0')
				{
					vSetSurvivorLight(admin, g_esDeveloper[admin].g_sDevFlashlight, .delimiter = ",");
				}

				if (g_esDeveloper[admin].g_sDevGlowOutline[0] != '\0')
				{
					vSetSurvivorOutline(admin, g_esDeveloper[admin].g_sDevGlowOutline, .delimiter = ",");
				}

				if (g_esDeveloper[admin].g_sDevSkinColor[0] != '\0')
				{
					vSetSurvivorColor(admin, g_esDeveloper[admin].g_sDevSkinColor, .delimiter = ",");
				}

				vSetSurvivorParticle(admin);
			}
			else if (g_esDeveloper[admin].g_bDevVisual)
			{
				g_esDeveloper[admin].g_bDevVisual = false;

				vToggleSurvivorEffects(admin);
			}
		}
	}
	else if (bIsValidClient(admin))
	{
		if (bIsValidClient(admin, MT_CHECK_ALIVE) && g_esDeveloper[admin].g_bDevVisual)
		{
			vToggleSurvivorEffects(admin);
		}

		g_esDeveloper[admin].g_bDevVisual = false;
	}
}

void vSurvivorReactions(int tank)
{
	char sModel[40];
	float flTankPos[3], flSurvivorPos[3];
	GetClientAbsOrigin(tank, flTankPos);
	for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
	{
		if (bIsSurvivor(iSurvivor, MT_CHECK_INGAME|MT_CHECK_ALIVE))
		{
			GetClientAbsOrigin(iSurvivor, flSurvivorPos);
			if (GetVectorDistance(flTankPos, flSurvivorPos) <= 500.0)
			{
				if (bIsValidClient(iSurvivor, MT_CHECK_FAKECLIENT))
				{
					vShakePlayerScreen(iSurvivor, 2.0);
				}
			}

			switch (MT_GetRandomInt(1, 5))
			{
				case 1:
				{
					GetEntPropString(iSurvivor, Prop_Data, "m_ModelName", sModel, sizeof sModel);

					switch (sModel[29])
					{
						case 'b', 'd', 'c', 'h': vForceVocalize(iSurvivor, "C2M1Falling");
						case 'v', 'n', 'e', 'a': vForceVocalize(iSurvivor, "PlaneCrashResponse");
					}
				}
				case 2: vForceVocalize(iSurvivor, "PlayerYellRun");
				case 3: vForceVocalize(iSurvivor, (g_bSecondGame ? "PlayerWarnTank" : "PlayerAlsoWarnTank"));
				case 4: vForceVocalize(iSurvivor, "PlayerBackUp");
				case 5: vForceVocalize(iSurvivor, "PlayerEmphaticGo");
			}
		}
	}

	int iExplosion = CreateEntityByName("env_explosion");
	if (bIsValidEntity(iExplosion))
	{
		DispatchKeyValue(iExplosion, "fireballsprite", SPRITE_EXPLODE);
		DispatchKeyValueInt(iExplosion, "iMagnitude", 50);
		DispatchKeyValueInt(iExplosion, "rendermode", 5);
		DispatchKeyValueInt(iExplosion, "spawnflags", 1);

		TeleportEntity(iExplosion, flTankPos);
		DispatchSpawn(iExplosion);

		SetEntPropEnt(iExplosion, Prop_Data, "m_hOwnerEntity", tank);
		SetEntProp(iExplosion, Prop_Send, "m_iTeamNum", 3);
		AcceptEntityInput(iExplosion, "Explode");

		iExplosion = EntIndexToEntRef(iExplosion);
		vDeleteEntity(iExplosion, 2.0);

		EmitSoundToAll((g_bSecondGame ? SOUND_EXPLOSION2 : SOUND_EXPLOSION1), iExplosion, 0, 75, 0, 1.0, 100, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
	}

	if (g_bSecondGame)
	{
		int iTimescale = CreateEntityByName("func_timescale");
		if (bIsValidEntity(iTimescale))
		{
			DispatchKeyValueFloat(iTimescale, "desiredTimescale", 0.2);
			DispatchKeyValueFloat(iTimescale, "acceleration", 2.0);
			DispatchKeyValueFloat(iTimescale, "minBlendRate", 1.0);
			DispatchKeyValueFloat(iTimescale, "blendDeltaMultiplier", 2.0);

			DispatchSpawn(iTimescale);
			AcceptEntityInput(iTimescale, "Start");

			CreateTimer(0.75, tTimerRemoveTimescale, EntIndexToEntRef(iTimescale), TIMER_FLAG_NO_MAPCHANGE);
		}
	}

	flTankPos[2] += 40.0;
	TE_SetupBeamRingPoint(flTankPos, 10.0, 2000.0, g_iBossBeamSprite, g_iBossHaloSprite, 0, 50, 1.0, 88.0, 3.0, {255, 255, 255, 50}, 1000, 0);
	TE_SendToAll();
	vPushNearbyEntities(tank, flTankPos);
}

void vToggleSurvivorEffects(int survivor, bool override = false, int type = -1, bool toggle = true)
{
	if (!override && bIsDeveloper(survivor, 0))
	{
		return;
	}

	if (type == -1 || type == 4)
	{
		char sDelimiter[2];
		sDelimiter = (FindCharInString(g_esPlayer[survivor].g_sLightColor, ';') != -1) ? ";" : ",";

		switch (toggle && g_esPlayer[survivor].g_flVisualTime[4] != -1.0 && g_esPlayer[survivor].g_flVisualTime[4] > GetGameTime())
		{
			case true: vSetSurvivorLight(survivor, g_esPlayer[survivor].g_sLightColor, g_esPlayer[survivor].g_bApplyVisuals[4], sDelimiter, true);
			case false: vRemoveSurvivorLight(survivor);
		}
	}

	if (type == -1 || type == 5)
	{
		char sDelimiter[2];
		sDelimiter = (FindCharInString(g_esPlayer[survivor].g_sBodyColor, ';') != -1) ? ";" : ",";

		switch (toggle && g_esPlayer[survivor].g_flVisualTime[5] != -1.0 && g_esPlayer[survivor].g_flVisualTime[5] > GetGameTime())
		{
			case true: vSetSurvivorColor(survivor, g_esPlayer[survivor].g_sBodyColor, g_esPlayer[survivor].g_bApplyVisuals[5], sDelimiter, true);
			case false:
			{
				SetEntityRenderMode(survivor, RENDER_NORMAL);
				SetEntityRenderColor(survivor, 255, 255, 255, 255);
			}
		}
	}

	if (type == -1 || type == 6)
	{
		char sDelimiter[2];
		sDelimiter = (FindCharInString(g_esPlayer[survivor].g_sOutlineColor, ';') != -1) ? ";" : ",";

		switch (toggle && g_esPlayer[survivor].g_flVisualTime[6] != -1.0 && g_esPlayer[survivor].g_flVisualTime[6] > GetGameTime())
		{
			case true: vSetSurvivorOutline(survivor, g_esPlayer[survivor].g_sOutlineColor, g_esPlayer[survivor].g_bApplyVisuals[6], sDelimiter, true);
			case false: vRemovePlayerGlow(survivor);
		}
	}
}

void vToggleWeaponVerticalPunch(int survivor, bool toggle)
{
	switch (toggle)
	{
		case true:
		{
			if ((bIsDeveloper(survivor, 4) || ((g_esPlayer[survivor].g_iRewardTypes & MT_REWARD_DAMAGEBOOST) && g_esPlayer[survivor].g_iRecoilDampener == 1)) && bIsValidClient(survivor, MT_CHECK_FAKECLIENT))
			{
				g_esGeneral.g_cvMTGunVerticalPunch.ReplicateToClient(survivor, "0");
			}
		}
		case false:
		{
			if (!bIsDeveloper(survivor, 4) && (!(g_esPlayer[survivor].g_iRewardTypes & MT_REWARD_DAMAGEBOOST) || g_esPlayer[survivor].g_iRecoilDampener == 0) && bIsValidClient(survivor, MT_CHECK_FAKECLIENT))
			{
				g_esGeneral.g_cvMTGunVerticalPunch.ReplicateToClient(survivor, g_esGeneral.g_sDefaultGunVerticalPunch);
			}
		}
	}
}

void vUnvomitPlayer(int player)
{
	if (g_esGeneral.g_hSDKITExpired != null)
	{
		SDKCall(g_esGeneral.g_hSDKITExpired, player);
	}
}

void vVocalizeTankDeath(int killer, int assistant, int tank)
{
	if (g_esCache[tank].g_iVocalizeDeath == 1)
	{
		if (bIsSurvivor(killer))
		{
			vForceVocalize(killer, "PlayerHurrah");
		}

		if (bIsSurvivor(assistant) && assistant != killer)
		{
			vForceVocalize(assistant, "PlayerTaunt");
		}

		for (int iTeammate = 1; iTeammate <= MaxClients; iTeammate++)
		{
			if (bIsSurvivor(iTeammate, MT_CHECK_INGAME|MT_CHECK_ALIVE) && g_esPlayer[iTeammate].g_iTankDamage[tank] > 0.0 && iTeammate != killer && iTeammate != assistant)
			{
				vForceVocalize(iTeammate, "PlayerNiceJob");
			}
		}
	}
}

/**
 * Tank functions
 **/

void vAnnounceTankArrival(int tank, const char[] name)
{
	if (!bIsCustomTank(tank) && !g_esGeneral.g_bFinaleEnded)
	{
		if (g_esCache[tank].g_iAnnounceArrival & MT_ARRIVAL_SPAWN)
		{
			int iOption = iGetMessageType(g_esCache[tank].g_iArrivalMessage);
			if (iOption > 0)
			{
				char sPhrase[32];
				FormatEx(sPhrase, sizeof sPhrase, "Arrival%i", iOption);
				MT_PrintToChatAll("%s %t", MT_TAG2, sPhrase, name);
				vLogMessage(MT_LOG_LIFE, _, "%s %T", MT_TAG, sPhrase, LANG_SERVER, name);
			}
		}

		if (g_esCache[tank].g_iVocalizeArrival == 1 || g_esCache[tank].g_iArrivalSound == 1)
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (g_esCache[tank].g_iVocalizeArrival == 1 && bIsSurvivor(iPlayer, MT_CHECK_INGAME|MT_CHECK_ALIVE))
				{
					switch (MT_GetRandomInt(1, 3))
					{
						case 1: vForceVocalize(iPlayer, "PlayerYellRun");
						case 2: vForceVocalize(iPlayer, (g_bSecondGame ? "PlayerWarnTank" : "PlayerAlsoWarnTank"));
						case 3: vForceVocalize(iPlayer, "PlayerBackUp");
					}
				}

				if (g_esCache[tank].g_iArrivalSound == 1 && bIsValidClient(iPlayer, MT_CHECK_INGAME|MT_CHECK_FAKECLIENT))
				{
					EmitSoundToClient(iPlayer, SOUND_SPAWN, iPlayer, SNDCHAN_WEAPON, SNDLEVEL_SCREAMING);
				}
			}
		}
	}
}

void vAnnounceTankDeath(int tank, int killer, float percentage, int assistant, float assistPercentage, bool override = true)
{
	bool bAnnounce = false;

	switch (g_esCache[tank].g_iAnnounceDeath)
	{
		case 1: bAnnounce = override;
		case 2:
		{
			int iOption = iGetMessageType(g_esCache[tank].g_iDeathMessage);
			if (iOption > 0)
			{
				char sDetails[128], sPhrase[32], sTankName[33], sTeammates[5][768];
				vGetTranslatedName(sTankName, sizeof sTankName, tank);
				if (bIsSurvivor(killer, MT_CHECK_INDEX|MT_CHECK_INGAME))
				{
					char sKiller[128];
					vRecordKiller(tank, killer, percentage, assistant, sKiller, sizeof sKiller);
					FormatEx(sPhrase, sizeof sPhrase, "Killer%i", iOption);
					vRecordDamage(tank, killer, assistant, assistPercentage, sDetails, sizeof sDetails, sTeammates, sizeof sTeammates, sizeof sTeammates[]);
					MT_PrintToChatAll("%s %t", MT_TAG2, sPhrase, sKiller, sTankName, sDetails);
					vLogMessage(MT_LOG_LIFE, _, "%s %T", MT_TAG, sPhrase, LANG_SERVER, sKiller, sTankName, sDetails);
					vShowDamageList(tank, sTankName, sTeammates, sizeof sTeammates);
					vVocalizeTankDeath(killer, assistant, tank);
				}
				else if (assistPercentage >= 1.0)
				{
					FormatEx(sPhrase, sizeof sPhrase, "Assist%i", iOption);
					vRecordDamage(tank, killer, assistant, assistPercentage, sDetails, sizeof sDetails, sTeammates, sizeof sTeammates, sizeof sTeammates[]);
					MT_PrintToChatAll("%s %t", MT_TAG2, sPhrase, sTankName, sDetails);
					vLogMessage(MT_LOG_LIFE, _, "%s %T", MT_TAG, sPhrase, LANG_SERVER, sTankName, sDetails);
					vShowDamageList(tank, sTankName, sTeammates, sizeof sTeammates);
					vVocalizeTankDeath(killer, assistant, tank);
				}
				else
				{
					bAnnounce = override;
				}
			}
		}
	}

	if (!bIsCustomTank(tank))
	{
		if (bAnnounce)
		{
			int iOption = iGetMessageType(g_esCache[tank].g_iDeathMessage);
			if (iOption > 0)
			{
				char sPhrase[32], sTankName[33];
				FormatEx(sPhrase, sizeof sPhrase, "Death%i", iOption);
				vGetTranslatedName(sTankName, sizeof sTankName, tank);
				MT_PrintToChatAll("%s %t", MT_TAG2, sPhrase, sTankName);
				vLogMessage(MT_LOG_LIFE, _, "%s %T", MT_TAG, sPhrase, LANG_SERVER, sTankName);
			}
		}

		if (g_esCache[tank].g_iVocalizeDeath == 1 || g_esCache[tank].g_iDeathSound == 1)
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (bAnnounce && g_esCache[tank].g_iVocalizeDeath == 1 && bIsSurvivor(iPlayer, MT_CHECK_INGAME|MT_CHECK_ALIVE))
				{
					switch (MT_GetRandomInt(1, 3))
					{
						case 1: vForceVocalize(iPlayer, "PlayerHurrah");
						case 2: vForceVocalize(iPlayer, "PlayerTaunt");
						case 3: vForceVocalize(iPlayer, "PlayerNiceJob");
					}
				}

				if (g_esCache[tank].g_iDeathSound == 1 && bIsValidClient(iPlayer, MT_CHECK_INGAME|MT_CHECK_FAKECLIENT))
				{
					EmitSoundToClient(iPlayer, SOUND_DEATH, iPlayer, SNDCHAN_WEAPON, SNDLEVEL_SCREAMING);
				}
			}
		}
	}
}

void vChangeTank(int admin, int amount, int mode)
{
	int iTarget = GetClientAimTarget(admin);

	switch (bIsTank(iTarget))
	{
		case true:
		{
			vSetTankColor(iTarget, g_esGeneral.g_iChosenType);
			vTankSpawn(iTarget, 5);
			vExternalView(iTarget, 1.5);

			g_esGeneral.g_iChosenType = 0;
		}
		case false: vSpawnTank(admin, .amount = amount, .mode = mode);
	}
}

void vChooseArrivalType(int tank, const char[] oldname, const char[] name, int mode)
{
	if (bIsTankSupported(tank))
	{
		if (!g_esGeneral.g_bFinaleEnded)
		{
			switch (mode)
			{
				case 0: vAnnounceTankArrival(tank, name);
				case 1:
				{
					if (g_esCache[tank].g_iAnnounceArrival & MT_ARRIVAL_BOSS)
					{
						MT_PrintToChatAll("%s %t", MT_TAG2, "Evolved", oldname, name, (g_esPlayer[tank].g_iBossStageCount + 1));
						vLogMessage(MT_LOG_CHANGE, _, "%s %T", MT_TAG, "Evolved", LANG_SERVER, oldname, name, (g_esPlayer[tank].g_iBossStageCount + 1));
					}
				}
				case 2:
				{
					if (g_esCache[tank].g_iAnnounceArrival & MT_ARRIVAL_RANDOM)
					{
						MT_PrintToChatAll("%s %t", MT_TAG2, "Randomized", oldname, name);
						vLogMessage(MT_LOG_CHANGE, _, "%s %T", MT_TAG, "Randomized", LANG_SERVER, oldname, name);
					}
				}
				case 3:
				{
					if (g_esCache[tank].g_iAnnounceArrival & MT_ARRIVAL_TRANSFORM)
					{
						MT_PrintToChatAll("%s %t", MT_TAG2, "Transformed", oldname, name);
						vLogMessage(MT_LOG_CHANGE, _, "%s %T", MT_TAG, "Transformed", LANG_SERVER, oldname, name);
					}
				}
				case 4:
				{
					if (g_esCache[tank].g_iAnnounceArrival & MT_ARRIVAL_REVERT)
					{
						MT_PrintToChatAll("%s %t", MT_TAG2, "Untransformed", oldname, name);
						vLogMessage(MT_LOG_CHANGE, _, "%s %T", MT_TAG, "Untransformed", LANG_SERVER, oldname, name);
					}
				}
				case 5:
				{
					vAnnounceTankArrival(tank, name);
					MT_PrintToChat(tank, "%s %t", MT_TAG3, "ChangeType");
				}
			}

			if (mode >= 0 && g_esCache[tank].g_iTankNote == 1 && bIsCustomTankSupported(tank))
			{
				char sPhrase[64], sSteamIDFinal[64], sTankNote[64];
				FormatEx(sSteamIDFinal, sizeof sSteamIDFinal, "%s", (TranslationPhraseExists(g_esPlayer[tank].g_sSteamID32) ? g_esPlayer[tank].g_sSteamID32 : g_esPlayer[tank].g_sSteam3ID));
				FormatEx(sPhrase, sizeof sPhrase, "Tank #%i", g_esTank[g_esPlayer[tank].g_iTankType].g_iRealType[0]);
				FormatEx(sTankNote, sizeof sTankNote, "%s", ((bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esPlayer[tank].g_iTankNote == 1 && sSteamIDFinal[0] != '\0') ? sSteamIDFinal : sPhrase));

				bool bExists = TranslationPhraseExists(sTankNote);
				MT_PrintToChatAll("%s %t", MT_TAG3, (bExists ? sTankNote : "NoNote"));
				vLogMessage(MT_LOG_LIFE, _, "%s %T", MT_TAG, (bExists ? sTankNote : "NoNote"), LANG_SERVER);
			}
		}

		switch (StrEqual(g_esCache[tank].g_sGlowColor, "rainbow", false))
		{
			case true:
			{
				if (!g_esPlayer[tank].g_bRainbowColor)
				{
					g_esPlayer[tank].g_bRainbowColor = SDKHookEx(tank, SDKHook_PreThinkPost, OnRainbowPreThinkPost);
				}
			}
			case false: vSetTankGlow(tank);
		}
	}
}

void vColorLight(int light, int red, int green, int blue, int alpha)
{
	char sColor[12];
	IntToString(alpha, sColor, sizeof sColor);
	DispatchKeyValue(light, "renderamt", sColor);

	FormatEx(sColor, sizeof sColor, "%i %i %i", red, green, blue);
	DispatchKeyValue(light, "rendercolor", sColor);
}

void vCopyTankStats(int tank, int newtank)
{
	SetEntProp(newtank, Prop_Data, "m_iMaxHealth", GetEntProp(tank, Prop_Data, "m_iMaxHealth"));

	g_esPlayer[newtank].g_bArtificial = g_esPlayer[tank].g_bArtificial;
	g_esPlayer[newtank].g_bBlood = g_esPlayer[tank].g_bBlood;
	g_esPlayer[newtank].g_bBlur = g_esPlayer[tank].g_bBlur;
	g_esPlayer[newtank].g_bBoss = g_esPlayer[tank].g_bBoss;
	g_esPlayer[newtank].g_bCombo = g_esPlayer[tank].g_bCombo;
	g_esPlayer[newtank].g_bElectric = g_esPlayer[tank].g_bElectric;
	g_esPlayer[newtank].g_bFire = g_esPlayer[tank].g_bFire;
	g_esPlayer[newtank].g_bFirstSpawn = g_esPlayer[tank].g_bFirstSpawn;
	g_esPlayer[newtank].g_bIce = g_esPlayer[tank].g_bIce;
	g_esPlayer[newtank].g_bKeepCurrentType = g_esPlayer[tank].g_bKeepCurrentType;
	g_esPlayer[newtank].g_bMeteor = g_esPlayer[tank].g_bMeteor;
	g_esPlayer[newtank].g_bRandomized = g_esPlayer[tank].g_bRandomized;
	g_esPlayer[newtank].g_bSmoke = g_esPlayer[tank].g_bSmoke;
	g_esPlayer[newtank].g_bSpit = g_esPlayer[tank].g_bSpit;
	g_esPlayer[newtank].g_bTransformed = g_esPlayer[tank].g_bTransformed;
	g_esPlayer[newtank].g_flLastAttackTime = g_esPlayer[tank].g_flLastAttackTime;
	g_esPlayer[newtank].g_flLastThrowTime = g_esPlayer[tank].g_flLastThrowTime;
	g_esPlayer[newtank].g_iBossStageCount = g_esPlayer[tank].g_iBossStageCount;
	g_esPlayer[newtank].g_iClawCount = g_esPlayer[tank].g_iClawCount;
	g_esPlayer[newtank].g_iClawDamage = g_esPlayer[tank].g_iClawDamage;
	g_esPlayer[newtank].g_iCooldown = g_esPlayer[tank].g_iCooldown;
	g_esPlayer[newtank].g_iIncapCount = g_esPlayer[tank].g_iIncapCount;
	g_esPlayer[newtank].g_iKillCount = g_esPlayer[tank].g_iKillCount;
	g_esPlayer[newtank].g_iMiscCount = g_esPlayer[tank].g_iMiscCount;
	g_esPlayer[newtank].g_iMiscDamage = g_esPlayer[tank].g_iMiscDamage;
	g_esPlayer[newtank].g_iOldTankType = g_esPlayer[tank].g_iOldTankType;
	g_esPlayer[newtank].g_iPropCount = g_esPlayer[tank].g_iPropCount;
	g_esPlayer[newtank].g_iPropDamage = g_esPlayer[tank].g_iPropDamage;
	g_esPlayer[newtank].g_iRockCount = g_esPlayer[tank].g_iRockCount;
	g_esPlayer[newtank].g_iRockDamage = g_esPlayer[tank].g_iRockDamage;
	g_esPlayer[newtank].g_iSurvivorDamage = g_esPlayer[tank].g_iSurvivorDamage;
	g_esPlayer[newtank].g_iTankHealth = g_esPlayer[tank].g_iTankHealth;
	g_esPlayer[newtank].g_iTankType = g_esPlayer[tank].g_iTankType;

	for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
	{
		g_esPlayer[iSurvivor].g_iTankDamage[newtank] = g_esPlayer[iSurvivor].g_iTankDamage[tank];
	}

	if (bIsValidClient(newtank, MT_CHECK_FAKECLIENT) && g_esGeneral.g_iSpawnMode != 2)
	{
		vTankMenu(newtank);
	}

	Call_StartForward(g_esGeneral.g_gfCopyStatsForward);
	Call_PushCell(tank);
	Call_PushCell(newtank);
	Call_Finish();
}

void vEvolveBoss(int tank, int limit, int stages, int type, int stage)
{
	if (stages >= stage && g_esPlayer[tank].g_iBossStageCount < stage)
	{
		int iHealth = GetEntProp(tank, Prop_Data, "m_iHealth");
		if (iHealth <= limit)
		{
			for (int iPos = 0; iPos < (sizeof esCache::g_iBossType); iPos++)
			{
				if (g_esCache[tank].g_iBossType[iPos] == g_esPlayer[tank].g_iTankType && iPos >= (stage - 1))
				{
					g_esPlayer[tank].g_iBossStageCount = (iPos + 1);

					return;
				}
			}

			g_esPlayer[tank].g_iBossStageCount = stage;

			if (g_esPlayer[tank].g_iTankType == type)
			{
				return;
			}

			vResetTankSpeed(tank);
			vSurvivorReactions(tank);
			vSetTankColor(tank, type, false);
			vTankSpawn(tank, 1);

			int iNewHealth = (GetEntProp(tank, Prop_Data, "m_iMaxHealth") + limit),
				iLeftover = (iNewHealth - iHealth),
				iLeftover2 = (iLeftover > MT_MAXHEALTH) ? (iLeftover - MT_MAXHEALTH) : iLeftover,
				iFinalHealth = (iNewHealth > MT_MAXHEALTH) ? MT_MAXHEALTH : iNewHealth;

			g_esPlayer[tank].g_iTankHealth += (iLeftover > MT_MAXHEALTH) ? iLeftover2 : iLeftover;
			SetEntProp(tank, Prop_Data, "m_iHealth", iFinalHealth);
			SetEntProp(tank, Prop_Data, "m_iMaxHealth", iFinalHealth);
		}
	}
}

void vFlashlightProp(int player, float origin[3], float angles[3], int colors[4])
{
	g_esPlayer[player].g_iFlashlight = CreateEntityByName("light_dynamic");
	if (bIsValidEntity(g_esPlayer[player].g_iFlashlight))
	{
		char sColor[16];
		FormatEx(sColor, sizeof sColor, "%i %i %i %i", iGetRandomColor(colors[0]), iGetRandomColor(colors[1]), iGetRandomColor(colors[2]), iGetRandomColor(colors[3]));
		DispatchKeyValue(g_esPlayer[player].g_iFlashlight, "_light", sColor);

		DispatchKeyValueInt(g_esPlayer[player].g_iFlashlight, "inner_cone", 0);
		DispatchKeyValueInt(g_esPlayer[player].g_iFlashlight, "cone", 80);
		DispatchKeyValueInt(g_esPlayer[player].g_iFlashlight, "brightness", 1);
		DispatchKeyValueFloat(g_esPlayer[player].g_iFlashlight, "spotlight_radius", 240.0);
		DispatchKeyValueFloat(g_esPlayer[player].g_iFlashlight, "distance", 255.0);
		DispatchKeyValueInt(g_esPlayer[player].g_iFlashlight, "pitch", -90);
		DispatchKeyValueInt(g_esPlayer[player].g_iFlashlight, "style", 5);

		float flOrigin[3], flAngles[3], flForward[3];
		GetClientEyePosition(player, origin);
		GetClientEyeAngles(player, angles);
		GetClientEyeAngles(player, flAngles);

		flAngles[0] = 0.0;
		flAngles[2] = 0.0;
		GetAngleVectors(flAngles, flForward, NULL_VECTOR, NULL_VECTOR);
		ScaleVector(flForward, -50.0);

		flForward[2] = 0.0;
		AddVectors(origin, flForward, flOrigin);

		angles[0] += 90.0;
		flOrigin[2] -= 120.0;
		AcceptEntityInput(g_esPlayer[player].g_iFlashlight, "TurnOn");
		TeleportEntity(g_esPlayer[player].g_iFlashlight, flOrigin, angles);
		DispatchSpawn(g_esPlayer[player].g_iFlashlight);
		vSetEntityParent(g_esPlayer[player].g_iFlashlight, player, true);

		if (bIsTank(player))
		{
			SDKHook(g_esPlayer[player].g_iFlashlight, SDKHook_SetTransmit, OnPropSetTransmit);
		}

		g_esPlayer[player].g_iFlashlight = EntIndexToEntRef(g_esPlayer[player].g_iFlashlight);
	}
}

void vKnockbackTank(int tank, int survivor, int damagetype)
{
	float flResult = ((damagetype & DMG_BULLET) || (damagetype & DMG_BUCKSHOT)) ? 1.0 : 10.0;
	if ((bIsDeveloper(survivor, 9) || ((g_esPlayer[survivor].g_iRewardTypes & MT_REWARD_DAMAGEBOOST) && g_esPlayer[survivor].g_iSledgehammerRounds == 1)) && !bIsPlayerIncapacitated(tank) && MT_GetRandomFloat(0.0, 100.0) <= flResult)
	{
		vPerformKnockback(tank, survivor);
	}
}

void vLifeLeech(int survivor, int damagetype = 0, int tank = 0, int type = 5)
{
	if (!bIsSurvivor(survivor) || bIsSurvivorDisabled(survivor) || (bIsTank(tank) && (bIsPlayerIncapacitated(tank) || bIsCustomTank(tank))) || (damagetype != 0 && !(damagetype & DMG_CLUB) && !(damagetype & DMG_SLASH)))
	{
		return;
	}

	bool bDeveloper = bIsDeveloper(survivor, type);
	int iLeech = 0;

	switch (type)
	{
		case 5: iLeech = (bDeveloper && g_esDeveloper[survivor].g_iDevLifeLeech > g_esPlayer[survivor].g_iLifeLeech) ? g_esDeveloper[survivor].g_iDevLifeLeech : g_esPlayer[survivor].g_iLifeLeech;
		case 7: iLeech = (bDeveloper && g_esDeveloper[survivor].g_iDevHealthRegen > g_esPlayer[survivor].g_iHealthRegen) ? g_esDeveloper[survivor].g_iDevHealthRegen : g_esPlayer[survivor].g_iHealthRegen;
		default: return;
	}

	if ((!bDeveloper && (!(g_esPlayer[survivor].g_iRewardTypes & MT_REWARD_HEALTH) || g_esPlayer[survivor].g_flRewardTime[0] == -1.0)) || iLeech == 0)
	{
		return;
	}

	float flTempHealth = flGetTempHealth(survivor, g_esGeneral.g_cvMTPainPillsDecayRate.FloatValue);
	int iHealth = GetEntProp(survivor, Prop_Data, "m_iHealth"), iMaxHealth = GetEntProp(survivor, Prop_Data, "m_iMaxHealth");
	if (g_esPlayer[survivor].g_iReviveCount > 0 || g_esPlayer[survivor].g_bLastLife)
	{
		switch ((flTempHealth + iLeech) > iMaxHealth)
		{
			case true: vSetTempHealth(survivor, float(iMaxHealth));
			case false: vSetTempHealth(survivor, (flTempHealth + iLeech));
		}
	}
	else
	{
		switch ((iHealth + iLeech) > iMaxHealth)
		{
			case true: SetEntProp(survivor, Prop_Data, "m_iHealth", iMaxHealth);
			case false: SetEntProp(survivor, Prop_Data, "m_iHealth", (iHealth + iLeech));
		}

		float flHealth = (flTempHealth - iLeech);
		vSetTempHealth(survivor, ((flHealth < 0.0) ? 0.0 : flHealth));
	}

	if ((iHealth + flGetTempHealth(survivor, g_esGeneral.g_cvMTPainPillsDecayRate.FloatValue)) > iMaxHealth)
	{
		vSetTempHealth(survivor, float(iMaxHealth - iHealth));
	}
}

void vLightProp(int tank, int light, float origin[3], float angles[3])
{
	g_esPlayer[tank].g_iLight[light] = CreateEntityByName("beam_spotlight");
	if (bIsValidEntity(g_esPlayer[tank].g_iLight[light]))
	{
		if (light < 3)
		{
			char sTargetName[64];
			FormatEx(sTargetName, sizeof sTargetName, "mutant_tank_light_%i_%i_%i", tank, g_esPlayer[tank].g_iTankType, light);
			DispatchKeyValue(g_esPlayer[tank].g_iLight[light], "targetname", sTargetName);

			DispatchKeyValueVector(g_esPlayer[tank].g_iLight[light], "origin", origin);
			DispatchKeyValueVector(g_esPlayer[tank].g_iLight[light], "angles", angles);
			DispatchKeyValueInt(g_esPlayer[tank].g_iLight[light], "fadescale", 1);
			DispatchKeyValueInt(g_esPlayer[tank].g_iLight[light], "fademindist", -1);

			vColorLight(g_esPlayer[tank].g_iLight[light], iGetRandomColor(g_esCache[tank].g_iLightColor[0]), iGetRandomColor(g_esCache[tank].g_iLightColor[1]), iGetRandomColor(g_esCache[tank].g_iLightColor[2]), iGetRandomColor(g_esCache[tank].g_iLightColor[3]));
		}
		else
		{
			DispatchKeyValueInt(g_esPlayer[tank].g_iLight[light], "haloscale", 100);
			vColorLight(g_esPlayer[tank].g_iLight[light], iGetRandomColor(g_esCache[tank].g_iCrownColor[0]), iGetRandomColor(g_esCache[tank].g_iCrownColor[1]), iGetRandomColor(g_esCache[tank].g_iCrownColor[2]), iGetRandomColor(g_esCache[tank].g_iCrownColor[3]));
		}

		DispatchKeyValueInt(g_esPlayer[tank].g_iLight[light], "spotlightwidth", 10);
		DispatchKeyValueInt(g_esPlayer[tank].g_iLight[light], "spotlightlength", 50);
		DispatchKeyValueInt(g_esPlayer[tank].g_iLight[light], "spawnflags", 3);
		DispatchKeyValueInt(g_esPlayer[tank].g_iLight[light], "maxspeed", 100);
		DispatchKeyValueFloat(g_esPlayer[tank].g_iLight[light], "HDRColorScale", 0.7);

		float flOrigin[3] = {0.0, 0.0, 70.0}, flAngles[3] = {-45.0, 0.0, 0.0};
		if (light < 3)
		{
			char sParentName[64], sTargetName[64];
			FormatEx(sTargetName, sizeof sTargetName, "mutant_tank_%i_%i_%i", tank, g_esPlayer[tank].g_iTankType, light);
			DispatchKeyValue(tank, "targetname", sTargetName);
			GetEntPropString(tank, Prop_Data, "m_iName", sParentName, sizeof sParentName);
			DispatchKeyValue(g_esPlayer[tank].g_iLight[light], "parentname", sParentName);

			SetVariantString(sParentName);
			AcceptEntityInput(g_esPlayer[tank].g_iLight[light], "SetParent", g_esPlayer[tank].g_iLight[light], g_esPlayer[tank].g_iLight[light]);
			SetEntPropEnt(g_esPlayer[tank].g_iLight[light], Prop_Data, "m_hOwnerEntity", tank);

			switch (light)
			{
				case 0:
				{
					SetVariantString("mouth");
					vSetVector(angles, -90.0, 0.0, 0.0);
				}
				case 1:
				{
					SetVariantString("rhand");
					vSetVector(angles, 90.0, 0.0, 0.0);
				}
				case 2:
				{
					SetVariantString("lhand");
					vSetVector(angles, -90.0, 0.0, 0.0);
				}
			}

			AcceptEntityInput(g_esPlayer[tank].g_iLight[light], "SetParentAttachment");
		}
		else
		{
			vSetEntityParent(g_esPlayer[tank].g_iLight[light], tank, true);

			switch (light)
			{
				case 3: flAngles[1] = 60.0;
				case 4: flAngles[1] = 120.0;
				case 5: flAngles[1] = 180.0;
				case 6: flAngles[1] = 240.0;
				case 7: flAngles[1] = 300.0;
				case 8: flAngles[1] = 360.0;
			}
		}

		AcceptEntityInput(g_esPlayer[tank].g_iLight[light], "Enable");
		AcceptEntityInput(g_esPlayer[tank].g_iLight[light], "DisableCollision");
		AcceptEntityInput(g_esPlayer[tank].g_iLight[light], "TurnOn");

		switch (light)
		{
			case 0, 1, 2: TeleportEntity(g_esPlayer[tank].g_iLight[light], .angles = angles);
			case 3, 4, 5, 6, 7, 8: TeleportEntity(g_esPlayer[tank].g_iLight[light], flOrigin, flAngles);
		}

		DispatchSpawn(g_esPlayer[tank].g_iLight[light]);
		SDKHook(g_esPlayer[tank].g_iLight[light], SDKHook_SetTransmit, OnPropSetTransmit);
		g_esPlayer[tank].g_iLight[light] = EntIndexToEntRef(g_esPlayer[tank].g_iLight[light]);
	}
}

void vMutateTank(int tank, int type)
{
	if (bCanTypeSpawn())
	{
		bool bVersus = bIsCompetitiveModeRound(2);
		int iType = 0;
		if (type == 0 && g_esPlayer[tank].g_iTankType <= 0)
		{
			if (bVersus)
			{
				iType = g_esGeneral.g_alCompTypes.Get(0);
				g_esGeneral.g_alCompTypes.Erase(0);

				vSetTankColor(tank, iType, false);
			}
			else
			{
				switch (g_esGeneral.g_bFinalMap)
				{
					case true: iType = iChooseTank(tank, 1, g_esGeneral.g_iFinaleMinTypes[g_esGeneral.g_iTankWave], g_esGeneral.g_iFinaleMaxTypes[g_esGeneral.g_iTankWave]);
					case false: iType = (g_esGeneral.g_bNormalMap && g_esGeneral.g_iRegularMode == 1 && g_esGeneral.g_iRegularWave == 1) ? iChooseTank(tank, 1, g_esGeneral.g_iRegularMinType, g_esGeneral.g_iRegularMaxType) : iChooseTank(tank, 1);
				}
			}

			if (!g_esGeneral.g_bForceSpawned)
			{
				DataPack dpCountCheck;
				CreateDataTimer(g_esGeneral.g_flExtrasDelay, tTimerTankCountCheck, dpCountCheck, TIMER_FLAG_NO_MAPCHANGE);
				dpCountCheck.WriteCell(GetClientUserId(tank));

				switch (g_esGeneral.g_bFinalMap)
				{
					case true:
					{
						switch (g_esGeneral.g_iFinaleAmount)
						{
							case 0: dpCountCheck.WriteCell(g_esGeneral.g_iFinaleWave[g_esGeneral.g_iTankWave]);
							default: dpCountCheck.WriteCell(g_esGeneral.g_iFinaleAmount);
						}
					}
					case false: dpCountCheck.WriteCell(g_esGeneral.g_iRegularAmount);
				}
			}
		}
		else if (type != -1)
		{
			switch (!bVersus || (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esPlayer[tank].g_iPersonalType == type))
			{
				case true:
				{
					iType = (type > 0) ? type : g_esPlayer[tank].g_iTankType;
					g_esPlayer[tank].g_iPersonalType = 0;

					vSetTankColor(tank, iType, false, .store = true);
				}
				case false:
				{
					iType = g_esGeneral.g_alCompTypes.Get(0);
					g_esGeneral.g_alCompTypes.Erase(0);

					vSetTankColor(tank, iType, false);
				}
			}
		}

		if (g_esPlayer[tank].g_iTankType > 0)
		{
			vTankSpawn(tank);
			CreateTimer(0.1, tTimerCheckTankView, GetClientUserId(tank), TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
			CreateTimer(1.0, tTimerTankUpdate, GetClientUserId(tank), TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);

			if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esPlayer[tank].g_iFavoriteType > 0 && iType != g_esPlayer[tank].g_iFavoriteType && g_esGeneral.g_iSpawnMode == 2)
			{
				vFavoriteMenu(tank);
			}
		}
		else
		{
			vCacheSettings(tank);
			vSetTankModel(tank);
			vSetTankHealth(tank);
			vResetTankSpeed(tank, false);

			SDKHook(tank, SDKHook_PostThinkPost, OnTankPostThinkPost);

			switch (bIsTankIdle(tank))
			{
				case true: CreateTimer(0.1, tTimerAnnounce2, GetClientUserId(tank), TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
				case false: vAnnounceTankArrival(tank, "NoName");
			}

			float flCurrentTime = GetGameTime();
			g_esPlayer[tank].g_flLastAttackTime = flCurrentTime;
			g_esPlayer[tank].g_flLastThrowTime = flCurrentTime;
			g_esPlayer[tank].g_iTankHealth = GetEntProp(tank, Prop_Data, "m_iMaxHealth");
			g_esGeneral.g_iTankCount++;
		}
	}

	g_esGeneral.g_bForceSpawned = false;
	g_esGeneral.g_iChosenType = 0;
}

void vParticleEffects(int tank)
{
	if (bIsTankSupported(tank) && g_esCache[tank].g_iBodyEffects > 0)
	{
		if ((g_esCache[tank].g_iBodyEffects & MT_PARTICLE_BLOOD) && !g_esPlayer[tank].g_bBlood)
		{
			g_esPlayer[tank].g_bBlood = true;

			CreateTimer(0.75, tTimerBloodEffect, GetClientUserId(tank), TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
		}

		if ((g_esCache[tank].g_iBodyEffects & MT_PARTICLE_ELECTRICITY) && !g_esPlayer[tank].g_bElectric)
		{
			g_esPlayer[tank].g_bElectric = true;

			CreateTimer(0.75, tTimerElectricEffect, GetClientUserId(tank), TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
		}

		if ((g_esCache[tank].g_iBodyEffects & MT_PARTICLE_FIRE) && !g_esPlayer[tank].g_bFire)
		{
			g_esPlayer[tank].g_bFire = true;

			CreateTimer(0.75, tTimerFireEffect, GetClientUserId(tank), TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
		}

		if ((g_esCache[tank].g_iBodyEffects & MT_PARTICLE_ICE) && !g_esPlayer[tank].g_bIce)
		{
			g_esPlayer[tank].g_bIce = true;

			CreateTimer(2.0, tTimerIceEffect, GetClientUserId(tank), TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
		}

		if ((g_esCache[tank].g_iBodyEffects & MT_PARTICLE_METEOR) && !g_esPlayer[tank].g_bMeteor)
		{
			g_esPlayer[tank].g_bMeteor = true;

			CreateTimer(6.0, tTimerMeteorEffect, GetClientUserId(tank), TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
		}

		if ((g_esCache[tank].g_iBodyEffects & MT_PARTICLE_SMOKE) && !g_esPlayer[tank].g_bSmoke)
		{
			g_esPlayer[tank].g_bSmoke = true;

			CreateTimer(1.5, tTimerSmokeEffect, GetClientUserId(tank), TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
		}

		if (g_bSecondGame && (g_esCache[tank].g_iBodyEffects & MT_PARTICLE_SPIT) && !g_esPlayer[tank].g_bSpit)
		{
			g_esPlayer[tank].g_bSpit = true;

			CreateTimer(2.0, tTimerSpitEffect, GetClientUserId(tank), TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
		}
	}
}

void vPerformKnockback(int special, int survivor)
{
	if (g_esGeneral.g_hSDKShovedBySurvivor != null)
	{
		float flTankOrigin[3], flSurvivorOrigin[3], flDirection[3];
		GetClientAbsOrigin(survivor, flSurvivorOrigin);
		GetClientAbsOrigin(special, flTankOrigin);
		MakeVectorFromPoints(flSurvivorOrigin, flTankOrigin, flDirection);
		NormalizeVector(flDirection, flDirection);
		SDKCall(g_esGeneral.g_hSDKShovedBySurvivor, special, survivor, flDirection);
	}

	SetEntPropFloat(special, Prop_Send, "m_flVelocityModifier", 0.4);
}

void vQueueTank(int admin, int type, bool mode = true, bool log = true)
{
	char sType[5];
	IntToString(type, sType, sizeof sType);
	vSetupTankSpawn(admin, sType, mode, log);
}

void vRegularSpawn()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
		{
			vCheatCommand(iPlayer, (g_bSecondGame ? "z_spawn_old" : "z_spawn"), "tank auto");

			break;
		}
	}
}

void vRemoveTankProps(int tank, int mode = 1)
{
	if (bIsValidEntRef(g_esPlayer[tank].g_iBlur))
	{
		g_esPlayer[tank].g_iBlur = EntRefToEntIndex(g_esPlayer[tank].g_iBlur);
		if (bIsValidEntity(g_esPlayer[tank].g_iBlur))
		{
			SDKUnhook(g_esPlayer[tank].g_iBlur, SDKHook_SetTransmit, OnPropSetTransmit);
			RemoveEntity(g_esPlayer[tank].g_iBlur);
		}
	}

	g_esPlayer[tank].g_iBlur = INVALID_ENT_REFERENCE;

	for (int iLight = 0; iLight < (sizeof esPlayer::g_iLight); iLight++)
	{
		if (bIsValidEntRef(g_esPlayer[tank].g_iLight[iLight]))
		{
			g_esPlayer[tank].g_iLight[iLight] = EntRefToEntIndex(g_esPlayer[tank].g_iLight[iLight]);
			if (bIsValidEntity(g_esPlayer[tank].g_iLight[iLight]))
			{
				SDKUnhook(g_esPlayer[tank].g_iLight[iLight], SDKHook_SetTransmit, OnPropSetTransmit);
				RemoveEntity(g_esPlayer[tank].g_iLight[iLight]);
			}
		}

		g_esPlayer[tank].g_iLight[iLight] = INVALID_ENT_REFERENCE;
	}

	for (int iOzTank = 0; iOzTank < (sizeof esPlayer::g_iFlame); iOzTank++)
	{
		if (bIsValidEntRef(g_esPlayer[tank].g_iFlame[iOzTank]))
		{
			g_esPlayer[tank].g_iFlame[iOzTank] = EntRefToEntIndex(g_esPlayer[tank].g_iFlame[iOzTank]);
			if (bIsValidEntity(g_esPlayer[tank].g_iFlame[iOzTank]))
			{
				SDKUnhook(g_esPlayer[tank].g_iFlame[iOzTank], SDKHook_SetTransmit, OnPropSetTransmit);
				RemoveEntity(g_esPlayer[tank].g_iFlame[iOzTank]);
			}
		}

		g_esPlayer[tank].g_iFlame[iOzTank] = INVALID_ENT_REFERENCE;

		if (bIsValidEntRef(g_esPlayer[tank].g_iOzTank[iOzTank]))
		{
			g_esPlayer[tank].g_iOzTank[iOzTank] = EntRefToEntIndex(g_esPlayer[tank].g_iOzTank[iOzTank]);
			if (bIsValidEntity(g_esPlayer[tank].g_iOzTank[iOzTank]))
			{
				SDKUnhook(g_esPlayer[tank].g_iOzTank[iOzTank], SDKHook_SetTransmit, OnPropSetTransmit);
				RemoveEntity(g_esPlayer[tank].g_iOzTank[iOzTank]);
			}
		}

		g_esPlayer[tank].g_iOzTank[iOzTank] = INVALID_ENT_REFERENCE;
	}

	for (int iRock = 0; iRock < (sizeof esPlayer::g_iRock); iRock++)
	{
		if (bIsValidEntRef(g_esPlayer[tank].g_iRock[iRock]))
		{
			g_esPlayer[tank].g_iRock[iRock] = EntRefToEntIndex(g_esPlayer[tank].g_iRock[iRock]);
			if (bIsValidEntity(g_esPlayer[tank].g_iRock[iRock]))
			{
				SDKUnhook(g_esPlayer[tank].g_iRock[iRock], SDKHook_SetTransmit, OnPropSetTransmit);
				RemoveEntity(g_esPlayer[tank].g_iRock[iRock]);
			}
		}

		g_esPlayer[tank].g_iRock[iRock] = INVALID_ENT_REFERENCE;
	}

	for (int iTire = 0; iTire < (sizeof esPlayer::g_iTire); iTire++)
	{
		if (bIsValidEntRef(g_esPlayer[tank].g_iTire[iTire]))
		{
			g_esPlayer[tank].g_iTire[iTire] = EntRefToEntIndex(g_esPlayer[tank].g_iTire[iTire]);
			if (bIsValidEntity(g_esPlayer[tank].g_iTire[iTire]))
			{
				SDKUnhook(g_esPlayer[tank].g_iTire[iTire], SDKHook_SetTransmit, OnPropSetTransmit);
				RemoveEntity(g_esPlayer[tank].g_iTire[iTire]);
			}
		}

		g_esPlayer[tank].g_iTire[iTire] = INVALID_ENT_REFERENCE;
	}

	if (bIsValidEntRef(g_esPlayer[tank].g_iPropaneTank))
	{
		g_esPlayer[tank].g_iPropaneTank = EntRefToEntIndex(g_esPlayer[tank].g_iPropaneTank);
		if (bIsValidEntity(g_esPlayer[tank].g_iPropaneTank))
		{
			SDKUnhook(g_esPlayer[tank].g_iPropaneTank, SDKHook_SetTransmit, OnPropSetTransmit);
			RemoveEntity(g_esPlayer[tank].g_iPropaneTank);
		}
	}

	g_esPlayer[tank].g_iPropaneTank = INVALID_ENT_REFERENCE;

	if (bIsValidEntRef(g_esPlayer[tank].g_iFlashlight))
	{
		g_esPlayer[tank].g_iFlashlight = EntRefToEntIndex(g_esPlayer[tank].g_iFlashlight);
		if (bIsValidEntity(g_esPlayer[tank].g_iFlashlight))
		{
			SDKUnhook(g_esPlayer[tank].g_iFlashlight, SDKHook_SetTransmit, OnPropSetTransmit);
			RemoveEntity(g_esPlayer[tank].g_iFlashlight);
		}
	}

	g_esPlayer[tank].g_iFlashlight = INVALID_ENT_REFERENCE;

	vRemovePlayerGlow(tank);

	if (mode == 1)
	{
		SetEntityRenderMode(tank, RENDER_NORMAL);
		SetEntityRenderColor(tank, 255, 255, 255, 255);
	}
}

void vResetTank(int tank, int mode = 1)
{
	vRemoveTankProps(tank, mode);
	vResetTankSpeed(tank);
	vSpawnModes(tank, false);
}

void vResetTank2(int tank, bool full = true)
{
	g_esPlayer[tank].g_bArtificial = false;
	g_esPlayer[tank].g_bBlood = false;
	g_esPlayer[tank].g_bBlur = false;
	g_esPlayer[tank].g_bElectric = false;
	g_esPlayer[tank].g_bFire = false;
	g_esPlayer[tank].g_bFirstSpawn = false;
	g_esPlayer[tank].g_bIce = false;
	g_esPlayer[tank].g_bKeepCurrentType = false;
	g_esPlayer[tank].g_bMeteor = false;
	g_esPlayer[tank].g_bReplaceSelf = false;
	g_esPlayer[tank].g_bSmoke = false;
	g_esPlayer[tank].g_bSpit = false;
	g_esPlayer[tank].g_flLastAttackTime = 0.0;
	g_esPlayer[tank].g_flLastThrowTime = 0.0;
	g_esPlayer[tank].g_iBossStageCount = 0;
	g_esPlayer[tank].g_iClawCount = 0;
	g_esPlayer[tank].g_iClawDamage = 0;
	g_esPlayer[tank].g_iCooldown = -1;
	g_esPlayer[tank].g_iIncapCount = 0;
	g_esPlayer[tank].g_iKillCount = 0;
	g_esPlayer[tank].g_iMiscCount = 0;
	g_esPlayer[tank].g_iMiscDamage = 0;
	g_esPlayer[tank].g_iOldTankType = 0;
	g_esPlayer[tank].g_iPropCount = 0;
	g_esPlayer[tank].g_iPropDamage = 0;
	g_esPlayer[tank].g_iRockCount = 0;
	g_esPlayer[tank].g_iRockDamage = 0;
	g_esPlayer[tank].g_iSurvivorDamage = 0;
	g_esPlayer[tank].g_iTankType = 0;

	for (int iPos = 0; iPos < (sizeof esPlayer::g_iThrownRock); iPos++)
	{
		g_esPlayer[tank].g_iThrownRock[iPos] = INVALID_ENT_REFERENCE;
	}

	if (full)
	{
		vResetSurvivorStats(tank, true);
	}
}

void vResetTank3(int tank)
{
	ExtinguishEntity(tank);
	EmitSoundToAll(SOUND_ELECTRICITY, tank);
	vAttachParticle(tank, PARTICLE_ELECTRICITY, 2.0, 30.0);
	vResetTankSpeed(tank);
	vRemovePlayerGlow(tank);
}

void vResetTankSpeed(int tank, bool mode = true)
{
	if (bIsValidClient(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE))
	{
		switch (mode || g_esCache[tank].g_flRunSpeed <= 0.0)
		{
			case true: SetEntPropFloat(tank, Prop_Send, "m_flLaggedMovementValue", 1.0);
			case false: SetEntPropFloat(tank, Prop_Send, "m_flLaggedMovementValue", g_esCache[tank].g_flRunSpeed);
		}
	}
}

void vSetRockColor(int rock)
{
	if (bIsValidEntity(rock) && bIsValidEntRef(g_esGeneral.g_iLauncher))
	{
		g_esGeneral.g_iLauncher = EntRefToEntIndex(g_esGeneral.g_iLauncher);
		if (bIsValidEntity(g_esGeneral.g_iLauncher))
		{
			int iTank = GetEntPropEnt(g_esGeneral.g_iLauncher, Prop_Data, "m_hOwnerEntity");
			if (bIsTankSupported(iTank))
			{
				SetEntPropEnt(rock, Prop_Data, "m_hThrower", iTank);
				SetEntPropEnt(rock, Prop_Data, "m_hOwnerEntity", g_esGeneral.g_iLauncher);
				vSetRockModel(iTank, rock);

				switch (StrEqual(g_esCache[iTank].g_sRockColor, "rainbow", false))
				{
					case true:
					{
						g_esPlayer[iTank].g_iThrownRock[rock] = EntIndexToEntRef(rock);

						if (!g_esPlayer[iTank].g_bRainbowColor)
						{
							g_esPlayer[iTank].g_bRainbowColor = SDKHookEx(iTank, SDKHook_PreThinkPost, OnRainbowPreThinkPost);
						}
					}
					case false: SetEntityRenderColor(rock, iGetRandomColor(g_esCache[iTank].g_iRockColor[0]), iGetRandomColor(g_esCache[iTank].g_iRockColor[1]), iGetRandomColor(g_esCache[iTank].g_iRockColor[2]), iGetRandomColor(g_esCache[iTank].g_iRockColor[3]));
				}
			}
		}
	}
}

void vSetRockModel(int tank, int rock)
{
	switch (g_esCache[tank].g_iRockModel)
	{
		case 0: SetEntityModel(rock, MODEL_CONCRETE_CHUNK);
		case 1: SetEntityModel(rock, MODEL_TREE_TRUNK);
		case 2: SetEntityModel(rock, ((MT_GetRandomInt(0, 1) == 0) ? MODEL_CONCRETE_CHUNK : MODEL_TREE_TRUNK));
	}
}

void vSetTankColor(int tank, int type = 0, bool change = true, bool revert = false, bool store = false)
{
	if (type == -1)
	{
		return;
	}

	if (g_esPlayer[tank].g_iTankType > 0)
	{
		if (change)
		{
			vResetTank3(tank);
		}

		if (type == 0)
		{
			vRemoveTankProps(tank);
			vChangeTypeForward(tank, g_esPlayer[tank].g_iTankType, type, revert);

			g_esPlayer[tank].g_iTankType = 0;

			return;
		}
		else if (g_esPlayer[tank].g_iTankType == type && !g_esPlayer[tank].g_bReplaceSelf && !g_esPlayer[tank].g_bKeepCurrentType)
		{
			g_esPlayer[tank].g_iTankType = 0;

			vRemoveTankProps(tank);
			vChangeTypeForward(tank, type, g_esPlayer[tank].g_iTankType, revert);

			return;
		}
		else if (type > 0)
		{
			g_esPlayer[tank].g_iOldTankType = g_esPlayer[tank].g_iTankType;
		}
	}

	if (store && bIsCompetitiveModeRound(1))
	{
		g_esGeneral.g_alCompTypes.Push(type);
	}

	g_esPlayer[tank].g_bReplaceSelf = false;
	g_esPlayer[tank].g_iTankType = type;

	vRemoveTankProps(tank);
	vChangeTypeForward(tank, g_esPlayer[tank].g_iOldTankType, g_esPlayer[tank].g_iTankType, revert);
	vCacheSettings(tank);
	vSetTankModel(tank);
	vRemovePlayerGlow(tank);
	vSetTankRainbowColor(tank);
}

void vSetTankGlow(int tank)
{
	if (!g_bSecondGame || g_esCache[tank].g_iGlowEnabled == 0)
	{
		return;
	}

	SetEntProp(tank, Prop_Send, "m_glowColorOverride", iGetRGBColor(iGetRandomColor(g_esCache[tank].g_iGlowColor[0]), iGetRandomColor(g_esCache[tank].g_iGlowColor[1]), iGetRandomColor(g_esCache[tank].g_iGlowColor[2])));
	SetEntProp(tank, Prop_Send, "m_bFlashing", g_esCache[tank].g_iGlowFlashing);
	SetEntProp(tank, Prop_Send, "m_nGlowRangeMin", g_esCache[tank].g_iGlowMinRange);
	SetEntProp(tank, Prop_Send, "m_nGlowRange", g_esCache[tank].g_iGlowMaxRange);
	SetEntProp(tank, Prop_Send, "m_iGlowType", ((bIsTankIdle(tank) || g_esCache[tank].g_iGlowType == 0) ? 2 : 3));
}

void vSetTankHealth(int tank, bool initial = true)
{
	int iHumanCount = iGetHumanCount(), iSpawnHealth = (g_esCache[tank].g_iBaseHealth > 0) ? g_esCache[tank].g_iBaseHealth : GetEntProp(tank, Prop_Data, "m_iHealth");
	float flMultiplier = (g_esCache[tank].g_iHumanMultiplierMode == 1) ? g_esCache[tank].g_flHealPercentMultiplier : (iHumanCount * g_esCache[tank].g_flHealPercentMultiplier);
	int iExtraHealthNormal = (iSpawnHealth + g_esCache[tank].g_iExtraHealth),
		iExtraHealthBoost = (iHumanCount >= g_esCache[tank].g_iMinimumHumans) ? (RoundToNearest(iSpawnHealth * flMultiplier) + g_esCache[tank].g_iExtraHealth) : iExtraHealthNormal,
		iExtraHealthBoost2 = (iHumanCount >= g_esCache[tank].g_iMinimumHumans) ? (iSpawnHealth + RoundToNearest(flMultiplier * g_esCache[tank].g_iExtraHealth)) : iExtraHealthNormal,
		iExtraHealthBoost3 = (iHumanCount >= g_esCache[tank].g_iMinimumHumans) ? RoundToNearest(flMultiplier * (iSpawnHealth + g_esCache[tank].g_iExtraHealth)) : iExtraHealthNormal,
		iNoBoost = (iExtraHealthNormal > MT_MAXHEALTH) ? MT_MAXHEALTH : iExtraHealthNormal,
		iBoost = (iExtraHealthBoost > MT_MAXHEALTH) ? MT_MAXHEALTH : iExtraHealthBoost,
		iBoost2 = (iExtraHealthBoost2 > MT_MAXHEALTH) ? MT_MAXHEALTH : iExtraHealthBoost2,
		iBoost3 = (iExtraHealthBoost3 > MT_MAXHEALTH) ? MT_MAXHEALTH : iExtraHealthBoost3,
		iNegaNoBoost = (iExtraHealthNormal < iSpawnHealth) ? 1 : iExtraHealthNormal,
		iNegaBoost = (iExtraHealthBoost < iSpawnHealth) ? 1 : iExtraHealthBoost,
		iNegaBoost2 = (iExtraHealthBoost2 < iSpawnHealth) ? 1 : iExtraHealthBoost2,
		iNegaBoost3 = (iExtraHealthBoost3 < iSpawnHealth) ? 1 : iExtraHealthBoost3,
		iFinalNoHealth = (iExtraHealthNormal >= 0) ? iNoBoost : iNegaNoBoost,
		iFinalHealth = (iExtraHealthNormal >= 0) ? iBoost : iNegaBoost,
		iFinalHealth2 = (iExtraHealthNormal >= 0) ? iBoost2 : iNegaBoost2,
		iFinalHealth3 = (iExtraHealthNormal >= 0) ? iBoost3 : iNegaBoost3,
		iTotalHealth = iFinalNoHealth,
		iHealth = GetEntProp(tank, Prop_Data, "m_iHealth"),
		iMaxHealth = GetEntProp(tank, Prop_Data, "m_iMaxHealth");

	switch (g_esCache[tank].g_iMultiplyHealth)
	{
		case 1: iTotalHealth = iFinalHealth;
		case 2: iTotalHealth = iFinalHealth2;
		case 3: iTotalHealth = iFinalHealth3;
	}

	float flPercentage = 1.0;
	if (!initial && iHealth != iMaxHealth)
	{
		flPercentage = float(iHealth) / float(iMaxHealth);
	}

	SetEntProp(tank, Prop_Data, "m_iHealth", RoundToNearest(iTotalHealth * flPercentage));
	SetEntProp(tank, Prop_Data, "m_iMaxHealth", iTotalHealth);
}

void vSetTankModel(int tank)
{
	if (g_esCache[tank].g_iTankModel > 0)
	{
		int iModelCount = 0, iModels[3], iFlag = 0;
		for (int iBit = 0; iBit < (sizeof iModels); iBit++)
		{
			iFlag = (1 << iBit);
			if (!(g_esCache[tank].g_iTankModel & iFlag))
			{
				continue;
			}

			iModels[iModelCount] = iFlag;
			iModelCount++;
		}

		if (iModelCount > 0)
		{
			switch (iModels[MT_GetRandomInt(0, (iModelCount - 1))])
			{
				case 1: SetEntityModel(tank, MODEL_TANK_MAIN);
				case 2: SetEntityModel(tank, MODEL_TANK_DLC);
				case 4: SetEntityModel(tank, (g_bSecondGame ? MODEL_TANK_L4D1 : MODEL_TANK_MAIN));
				default:
				{
					switch (MT_GetRandomInt(1, (sizeof iModels)))
					{
						case 1: SetEntityModel(tank, MODEL_TANK_MAIN);
						case 2: SetEntityModel(tank, MODEL_TANK_DLC);
						case 3: SetEntityModel(tank, (g_bSecondGame ? MODEL_TANK_L4D1 : MODEL_TANK_MAIN));
					}
				}
			}
		}
	}

	if (g_esCache[tank].g_flBurntSkin >= 0.01)
	{
		SetEntPropFloat(tank, Prop_Send, "m_burnPercent", g_esCache[tank].g_flBurntSkin);
	}
	else if (g_esCache[tank].g_flBurntSkin == 0.0)
	{
		SetEntPropFloat(tank, Prop_Send, "m_burnPercent", MT_GetRandomFloat(0.01, 1.0));
	}
}

void vSetTankName(int tank, const char[] oldname, const char[] name, int mode)
{
	if (bIsTankSupported(tank))
	{
		if (!bIsTank(tank, MT_CHECK_FAKECLIENT))
		{
			if (g_esCache[tank].g_sTankName[0] == '\0')
			{
				g_esCache[tank].g_sTankName = "Tank";
			}

			g_esGeneral.g_bHideNameChange = true;
			SetClientName(tank, g_esCache[tank].g_sTankName);
			g_esGeneral.g_bHideNameChange = false;
		}

		switch (mode == 0 || mode == 5)
		{
			case true:
			{
				DataPack dpAnnounce;
				CreateDataTimer(0.1, tTimerAnnounce, dpAnnounce, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
				dpAnnounce.WriteCell(GetClientUserId(tank));
				dpAnnounce.WriteString(oldname);
				dpAnnounce.WriteString(name);
				dpAnnounce.WriteCell(mode);
			}
			case false: vChooseArrivalType(tank, oldname, name, mode);
		}
	}
}

void vSetTankProps(int tank)
{
	if (bIsTankSupported(tank))
	{
		if (MT_GetRandomFloat(0.1, 100.0) <= g_esCache[tank].g_flPropsChance[0] && (g_esCache[tank].g_iPropsAttached & MT_PROP_BLUR) && !g_esPlayer[tank].g_bBlur)
		{
			float flTankPos[3], flTankAngles[3];
			GetClientAbsOrigin(tank, flTankPos);
			GetClientAbsAngles(tank, flTankAngles);

			g_esPlayer[tank].g_iBlur = CreateEntityByName("prop_dynamic");
			if (bIsValidEntity(g_esPlayer[tank].g_iBlur))
			{
				g_esPlayer[tank].g_bBlur = true;

				char sModel[32];
				GetEntPropString(tank, Prop_Data, "m_ModelName", sModel, sizeof sModel);

				switch (sModel[21])
				{
					case 'm': SetEntityModel(g_esPlayer[tank].g_iBlur, MODEL_TANK_MAIN);
					case 'd': SetEntityModel(g_esPlayer[tank].g_iBlur, MODEL_TANK_DLC);
					case 'l': SetEntityModel(g_esPlayer[tank].g_iBlur, MODEL_TANK_L4D1);
				}

				switch (StrEqual(g_esCache[tank].g_sSkinColor, "rainbow", false))
				{
					case true:
					{
						if (!g_esPlayer[tank].g_bRainbowColor)
						{
							g_esPlayer[tank].g_bRainbowColor = SDKHookEx(tank, SDKHook_PreThinkPost, OnRainbowPreThinkPost);
						}
					}
					case false:
					{
						int iColor[4];
						GetEntityRenderColor(tank, iColor[0], iColor[1], iColor[2], iColor[3]);
						SetEntityRenderColor(g_esPlayer[tank].g_iBlur, iColor[0], iColor[1], iColor[2], iColor[3]);
					}
				}

				SetEntPropEnt(g_esPlayer[tank].g_iBlur, Prop_Data, "m_hOwnerEntity", tank);

				TeleportEntity(g_esPlayer[tank].g_iBlur, flTankPos, flTankAngles);
				DispatchSpawn(g_esPlayer[tank].g_iBlur);

				AcceptEntityInput(g_esPlayer[tank].g_iBlur, "DisableCollision");
				SetEntProp(g_esPlayer[tank].g_iBlur, Prop_Send, "m_nSequence", GetEntProp(tank, Prop_Send, "m_nSequence"));
				SetEntPropFloat(g_esPlayer[tank].g_iBlur, Prop_Send, "m_flPlaybackRate", 5.0);

				SDKHook(g_esPlayer[tank].g_iBlur, SDKHook_SetTransmit, OnPropSetTransmit);
				g_esPlayer[tank].g_iBlur = EntIndexToEntRef(g_esPlayer[tank].g_iBlur);

				CreateTimer(0.1, tTimerBlurEffect, GetClientUserId(tank), TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
			}
		}

		float flOrigin[3], flAngles[3];
		GetEntPropVector(tank, Prop_Data, "m_vecOrigin", flOrigin);
		GetEntPropVector(tank, Prop_Data, "m_angRotation", flAngles);

		float flChance = MT_GetRandomFloat(0.1, 100.0), flValue = 0.0;
		int iFlag = 0, iType = 0;
		for (int iLight = 0; iLight < (sizeof esPlayer::g_iLight); iLight++)
		{
			flValue = (iLight < 3) ? MT_GetRandomFloat(0.1, 100.0) : flChance;
			iFlag = (iLight < 3) ? MT_PROP_LIGHT : MT_PROP_CROWN;
			iType = (iLight < 3) ? 1 : 8;
			if ((g_esPlayer[tank].g_iLight[iLight] == 0 || g_esPlayer[tank].g_iLight[iLight] == INVALID_ENT_REFERENCE) && flValue <= g_esCache[tank].g_flPropsChance[iType] && (g_esCache[tank].g_iPropsAttached & iFlag))
			{
				vLightProp(tank, iLight, flOrigin, flAngles);
			}
			else if (bIsValidEntRef(g_esPlayer[tank].g_iLight[iLight]))
			{
				g_esPlayer[tank].g_iLight[iLight] = EntRefToEntIndex(g_esPlayer[tank].g_iLight[iLight]);
				if (bIsValidEntity(g_esPlayer[tank].g_iLight[iLight]))
				{
					SDKUnhook(g_esPlayer[tank].g_iLight[iLight], SDKHook_SetTransmit, OnPropSetTransmit);
					RemoveEntity(g_esPlayer[tank].g_iLight[iLight]);
				}

				g_esPlayer[tank].g_iLight[iLight] = INVALID_ENT_REFERENCE;
				if (g_esCache[tank].g_iPropsAttached & iFlag)
				{
					vLightProp(tank, iLight, flOrigin, flAngles);
				}
			}
		}

		GetEntPropVector(tank, Prop_Data, "m_vecOrigin", flOrigin);
		GetEntPropVector(tank, Prop_Data, "m_angRotation", flAngles);

		float flOrigin2[3], flAngles2[3] = {0.0, 0.0, 90.0};
		for (int iOzTank = 0; iOzTank < (sizeof esPlayer::g_iOzTank); iOzTank++)
		{
			if ((g_esPlayer[tank].g_iOzTank[iOzTank] == 0 || g_esPlayer[tank].g_iOzTank[iOzTank] == INVALID_ENT_REFERENCE) && MT_GetRandomFloat(0.1, 100.0) <= g_esCache[tank].g_flPropsChance[2] && (g_esCache[tank].g_iPropsAttached & MT_PROP_OXYGENTANK))
			{
				g_esPlayer[tank].g_iOzTank[iOzTank] = CreateEntityByName("prop_dynamic_override");
				if (bIsValidEntity(g_esPlayer[tank].g_iOzTank[iOzTank]))
				{
					SetEntityModel(g_esPlayer[tank].g_iOzTank[iOzTank], MODEL_OXYGENTANK);
					SetEntityRenderColor(g_esPlayer[tank].g_iOzTank[iOzTank], iGetRandomColor(g_esCache[tank].g_iOzTankColor[0]), iGetRandomColor(g_esCache[tank].g_iOzTankColor[1]), iGetRandomColor(g_esCache[tank].g_iOzTankColor[2]), iGetRandomColor(g_esCache[tank].g_iOzTankColor[3]));

					DispatchKeyValueVector(g_esPlayer[tank].g_iOzTank[iOzTank], "origin", flOrigin);
					DispatchKeyValueVector(g_esPlayer[tank].g_iOzTank[iOzTank], "angles", flAngles);
					vSetEntityParent(g_esPlayer[tank].g_iOzTank[iOzTank], tank, true);

					switch (iOzTank)
					{
						case 0:
						{
							SetVariantString("rfoot");
							vSetVector(flOrigin2, 0.0, 30.0, 8.0);
						}
						case 1:
						{
							SetVariantString("lfoot");
							vSetVector(flOrigin2, 0.0, 30.0, -8.0);
						}
					}

					AcceptEntityInput(g_esPlayer[tank].g_iOzTank[iOzTank], "SetParentAttachment");
					AcceptEntityInput(g_esPlayer[tank].g_iOzTank[iOzTank], "Enable");
					AcceptEntityInput(g_esPlayer[tank].g_iOzTank[iOzTank], "DisableCollision");
					TeleportEntity(g_esPlayer[tank].g_iOzTank[iOzTank], flOrigin2, flAngles2);
					DispatchSpawn(g_esPlayer[tank].g_iOzTank[iOzTank]);

					SDKHook(g_esPlayer[tank].g_iOzTank[iOzTank], SDKHook_SetTransmit, OnPropSetTransmit);
					g_esPlayer[tank].g_iOzTank[iOzTank] = EntIndexToEntRef(g_esPlayer[tank].g_iOzTank[iOzTank]);

					if ((g_esPlayer[tank].g_iFlame[iOzTank] == 0 || g_esPlayer[tank].g_iFlame[iOzTank] == INVALID_ENT_REFERENCE) && MT_GetRandomFloat(0.1, 100.0) <= g_esCache[tank].g_flPropsChance[3] && (g_esCache[tank].g_iPropsAttached & MT_PROP_FLAME))
					{
						g_esPlayer[tank].g_iFlame[iOzTank] = CreateEntityByName("env_steam");
						if (bIsValidEntity(g_esPlayer[tank].g_iFlame[iOzTank]))
						{
							SetEntityRenderColor(g_esPlayer[tank].g_iFlame[iOzTank], iGetRandomColor(g_esCache[tank].g_iFlameColor[0]), iGetRandomColor(g_esCache[tank].g_iFlameColor[1]), iGetRandomColor(g_esCache[tank].g_iFlameColor[2]), iGetRandomColor(g_esCache[tank].g_iFlameColor[3]));

							DispatchKeyValueVector(g_esPlayer[tank].g_iFlame[iOzTank], "origin", flOrigin);
							vSetEntityParent(g_esPlayer[tank].g_iFlame[iOzTank], g_esPlayer[tank].g_iOzTank[iOzTank], true);

							DispatchKeyValueInt(g_esPlayer[tank].g_iFlame[iOzTank], "spawnflags", 1);
							DispatchKeyValueInt(g_esPlayer[tank].g_iFlame[iOzTank], "Type", 0);
							DispatchKeyValueInt(g_esPlayer[tank].g_iFlame[iOzTank], "InitialState", 1);
							DispatchKeyValueInt(g_esPlayer[tank].g_iFlame[iOzTank], "Spreadspeed", 1);
							DispatchKeyValueInt(g_esPlayer[tank].g_iFlame[iOzTank], "Speed", 250);
							DispatchKeyValueInt(g_esPlayer[tank].g_iFlame[iOzTank], "Startsize", 6);
							DispatchKeyValueInt(g_esPlayer[tank].g_iFlame[iOzTank], "EndSize", 8);
							DispatchKeyValueInt(g_esPlayer[tank].g_iFlame[iOzTank], "Rate", 555);
							DispatchKeyValueInt(g_esPlayer[tank].g_iFlame[iOzTank], "JetLength", 40);

							float flOrigin3[3] = {-2.0, 0.0, 28.0}, flAngles3[3] = {-90.0, 0.0, -90.0};
							AcceptEntityInput(g_esPlayer[tank].g_iFlame[iOzTank], "TurnOn");
							TeleportEntity(g_esPlayer[tank].g_iFlame[iOzTank], flOrigin3, flAngles3);
							DispatchSpawn(g_esPlayer[tank].g_iFlame[iOzTank]);

							SDKHook(g_esPlayer[tank].g_iFlame[iOzTank], SDKHook_SetTransmit, OnPropSetTransmit);
							g_esPlayer[tank].g_iFlame[iOzTank] = EntIndexToEntRef(g_esPlayer[tank].g_iFlame[iOzTank]);
						}
					}
				}
			}
			else if (bIsValidEntRef(g_esPlayer[tank].g_iOzTank[iOzTank]))
			{
				g_esPlayer[tank].g_iOzTank[iOzTank] = EntRefToEntIndex(g_esPlayer[tank].g_iOzTank[iOzTank]);
				if (bIsValidEntity(g_esPlayer[tank].g_iOzTank[iOzTank]) && (g_esCache[tank].g_iPropsAttached & MT_PROP_OXYGENTANK))
				{
					SetEntityRenderColor(g_esPlayer[tank].g_iOzTank[iOzTank], iGetRandomColor(g_esCache[tank].g_iOzTankColor[0]), iGetRandomColor(g_esCache[tank].g_iOzTankColor[1]), iGetRandomColor(g_esCache[tank].g_iOzTankColor[2]), iGetRandomColor(g_esCache[tank].g_iOzTankColor[3]));
				}
				else
				{
					if (bIsValidEntity(g_esPlayer[tank].g_iOzTank[iOzTank]))
					{
						SDKUnhook(g_esPlayer[tank].g_iOzTank[iOzTank], SDKHook_SetTransmit, OnPropSetTransmit);
						RemoveEntity(g_esPlayer[tank].g_iOzTank[iOzTank]);
					}

					g_esPlayer[tank].g_iOzTank[iOzTank] = INVALID_ENT_REFERENCE;
				}

				if (bIsValidEntRef(g_esPlayer[tank].g_iFlame[iOzTank]))
				{
					g_esPlayer[tank].g_iFlame[iOzTank] = EntRefToEntIndex(g_esPlayer[tank].g_iFlame[iOzTank]);
					if (bIsValidEntity(g_esPlayer[tank].g_iFlame[iOzTank]) && (g_esCache[tank].g_iPropsAttached & MT_PROP_FLAME))
					{
						SetEntityRenderColor(g_esPlayer[tank].g_iFlame[iOzTank], iGetRandomColor(g_esCache[tank].g_iFlameColor[0]), iGetRandomColor(g_esCache[tank].g_iFlameColor[1]), iGetRandomColor(g_esCache[tank].g_iFlameColor[2]), iGetRandomColor(g_esCache[tank].g_iFlameColor[3]));
					}
					else
					{
						if (bIsValidEntity(g_esPlayer[tank].g_iFlame[iOzTank]))
						{
							SDKUnhook(g_esPlayer[tank].g_iFlame[iOzTank], SDKHook_SetTransmit, OnPropSetTransmit);
							RemoveEntity(g_esPlayer[tank].g_iFlame[iOzTank]);
						}

						g_esPlayer[tank].g_iFlame[iOzTank] = INVALID_ENT_REFERENCE;
					}
				}
			}
		}

		GetEntPropVector(tank, Prop_Data, "m_vecOrigin", flOrigin);
		GetEntPropVector(tank, Prop_Data, "m_angRotation", flAngles);

		for (int iRock = 0; iRock < (sizeof esPlayer::g_iRock); iRock++)
		{
			if ((g_esPlayer[tank].g_iRock[iRock] == 0 || g_esPlayer[tank].g_iRock[iRock] == INVALID_ENT_REFERENCE) && MT_GetRandomFloat(0.1, 100.0) <= g_esCache[tank].g_flPropsChance[4] && (g_esCache[tank].g_iPropsAttached & MT_PROP_ROCK))
			{
				g_esPlayer[tank].g_iRock[iRock] = CreateEntityByName("prop_dynamic_override");
				if (bIsValidEntity(g_esPlayer[tank].g_iRock[iRock]))
				{
					SetEntityRenderColor(g_esPlayer[tank].g_iRock[iRock], iGetRandomColor(g_esCache[tank].g_iRockColor[0]), iGetRandomColor(g_esCache[tank].g_iRockColor[1]), iGetRandomColor(g_esCache[tank].g_iRockColor[2]), iGetRandomColor(g_esCache[tank].g_iRockColor[3]));
					vSetRockModel(tank, g_esPlayer[tank].g_iRock[iRock]);

					DispatchKeyValueVector(g_esPlayer[tank].g_iRock[iRock], "origin", flOrigin);
					DispatchKeyValueVector(g_esPlayer[tank].g_iRock[iRock], "angles", flAngles);
					vSetEntityParent(g_esPlayer[tank].g_iRock[iRock], tank, true);

					switch (iRock)
					{
						case 0, 4, 8, 12, 16: SetVariantString("rshoulder");
						case 1, 5, 9, 13, 17: SetVariantString("lshoulder");
						case 2, 6, 10, 14, 18: SetVariantString("relbow");
						case 3, 7, 11, 15, 19: SetVariantString("lelbow");
					}

					AcceptEntityInput(g_esPlayer[tank].g_iRock[iRock], "SetParentAttachment");
					AcceptEntityInput(g_esPlayer[tank].g_iRock[iRock], "Enable");
					AcceptEntityInput(g_esPlayer[tank].g_iRock[iRock], "DisableCollision");

					if (g_bSecondGame)
					{
						switch (iRock)
						{
							case 0, 1, 4, 5, 8, 9, 12, 13, 16, 17: SetEntPropFloat(g_esPlayer[tank].g_iRock[iRock], Prop_Data, "m_flModelScale", 0.4);
							case 2, 3, 6, 7, 10, 11, 14, 15, 18, 19: SetEntPropFloat(g_esPlayer[tank].g_iRock[iRock], Prop_Data, "m_flModelScale", 0.5);
						}
					}

					flAngles[0] += MT_GetRandomFloat(-90.0, 90.0);
					flAngles[1] += MT_GetRandomFloat(-90.0, 90.0);
					flAngles[2] += MT_GetRandomFloat(-90.0, 90.0);

					TeleportEntity(g_esPlayer[tank].g_iRock[iRock], .angles = flAngles);
					DispatchSpawn(g_esPlayer[tank].g_iRock[iRock]);

					SDKHook(g_esPlayer[tank].g_iRock[iRock], SDKHook_SetTransmit, OnPropSetTransmit);
					g_esPlayer[tank].g_iRock[iRock] = EntIndexToEntRef(g_esPlayer[tank].g_iRock[iRock]);
				}
			}
			else if (bIsValidEntRef(g_esPlayer[tank].g_iRock[iRock]))
			{
				g_esPlayer[tank].g_iRock[iRock] = EntRefToEntIndex(g_esPlayer[tank].g_iRock[iRock]);
				if (bIsValidEntity(g_esPlayer[tank].g_iRock[iRock]) && (g_esCache[tank].g_iPropsAttached & MT_PROP_ROCK))
				{
					SetEntityRenderColor(g_esPlayer[tank].g_iRock[iRock], iGetRandomColor(g_esCache[tank].g_iRockColor[0]), iGetRandomColor(g_esCache[tank].g_iRockColor[1]), iGetRandomColor(g_esCache[tank].g_iRockColor[2]), iGetRandomColor(g_esCache[tank].g_iRockColor[3]));
					vSetRockModel(tank, g_esPlayer[tank].g_iRock[iRock]);
				}
				else
				{
					if (bIsValidEntity(g_esPlayer[tank].g_iRock[iRock]))
					{
						SDKUnhook(g_esPlayer[tank].g_iRock[iRock], SDKHook_SetTransmit, OnPropSetTransmit);
						RemoveEntity(g_esPlayer[tank].g_iRock[iRock]);
					}

					g_esPlayer[tank].g_iRock[iRock] = INVALID_ENT_REFERENCE;
				}
			}
		}

		GetEntPropVector(tank, Prop_Data, "m_vecOrigin", flOrigin);
		GetEntPropVector(tank, Prop_Data, "m_angRotation", flAngles);
		flAngles[0] += 90.0;

		for (int iTire = 0; iTire < (sizeof esPlayer::g_iTire); iTire++)
		{
			if ((g_esPlayer[tank].g_iTire[iTire] == 0 || g_esPlayer[tank].g_iTire[iTire] == INVALID_ENT_REFERENCE) && MT_GetRandomFloat(0.1, 100.0) <= g_esCache[tank].g_flPropsChance[5] && (g_esCache[tank].g_iPropsAttached & MT_PROP_TIRE))
			{
				g_esPlayer[tank].g_iTire[iTire] = CreateEntityByName("prop_dynamic_override");
				if (bIsValidEntity(g_esPlayer[tank].g_iTire[iTire]))
				{
					SetEntityModel(g_esPlayer[tank].g_iTire[iTire], MODEL_TIRES);
					SetEntityRenderColor(g_esPlayer[tank].g_iTire[iTire], iGetRandomColor(g_esCache[tank].g_iTireColor[0]), iGetRandomColor(g_esCache[tank].g_iTireColor[1]), iGetRandomColor(g_esCache[tank].g_iTireColor[2]), iGetRandomColor(g_esCache[tank].g_iTireColor[3]));

					DispatchKeyValueVector(g_esPlayer[tank].g_iTire[iTire], "origin", flOrigin);
					DispatchKeyValueVector(g_esPlayer[tank].g_iTire[iTire], "angles", flAngles);
					vSetEntityParent(g_esPlayer[tank].g_iTire[iTire], tank, true);

					switch (iTire)
					{
						case 0: SetVariantString("rfoot");
						case 1: SetVariantString("lfoot");
					}

					AcceptEntityInput(g_esPlayer[tank].g_iTire[iTire], "SetParentAttachment");
					AcceptEntityInput(g_esPlayer[tank].g_iTire[iTire], "Enable");
					AcceptEntityInput(g_esPlayer[tank].g_iTire[iTire], "DisableCollision");

					if (g_bSecondGame)
					{
						SetEntPropFloat(g_esPlayer[tank].g_iTire[iTire], Prop_Data, "m_flModelScale", 1.5);
					}

					TeleportEntity(g_esPlayer[tank].g_iTire[iTire], .angles = flAngles);
					DispatchSpawn(g_esPlayer[tank].g_iTire[iTire]);

					SDKHook(g_esPlayer[tank].g_iTire[iTire], SDKHook_SetTransmit, OnPropSetTransmit);
					g_esPlayer[tank].g_iTire[iTire] = EntIndexToEntRef(g_esPlayer[tank].g_iTire[iTire]);
				}
			}
			else if (bIsValidEntRef(g_esPlayer[tank].g_iTire[iTire]))
			{
				g_esPlayer[tank].g_iTire[iTire] = EntRefToEntIndex(g_esPlayer[tank].g_iTire[iTire]);
				if (bIsValidEntity(g_esPlayer[tank].g_iTire[iTire]) && (g_esCache[tank].g_iPropsAttached & MT_PROP_TIRE))
				{
					SetEntityRenderColor(g_esPlayer[tank].g_iTire[iTire], iGetRandomColor(g_esCache[tank].g_iTireColor[0]), iGetRandomColor(g_esCache[tank].g_iTireColor[1]), iGetRandomColor(g_esCache[tank].g_iTireColor[2]), iGetRandomColor(g_esCache[tank].g_iTireColor[3]));
				}
				else
				{
					if (bIsValidEntity(g_esPlayer[tank].g_iTire[iTire]))
					{
						SDKUnhook(g_esPlayer[tank].g_iTire[iTire], SDKHook_SetTransmit, OnPropSetTransmit);
						RemoveEntity(g_esPlayer[tank].g_iTire[iTire]);
					}

					g_esPlayer[tank].g_iTire[iTire] = INVALID_ENT_REFERENCE;
				}
			}
		}

		GetEntPropVector(tank, Prop_Data, "m_vecOrigin", flOrigin);
		GetEntPropVector(tank, Prop_Data, "m_angRotation", flAngles);

		if ((g_esPlayer[tank].g_iPropaneTank == 0 || g_esPlayer[tank].g_iPropaneTank == INVALID_ENT_REFERENCE) && MT_GetRandomFloat(0.1, 100.0) <= g_esCache[tank].g_flPropsChance[6] && (g_esCache[tank].g_iPropsAttached & MT_PROP_PROPANETANK))
		{
			g_esPlayer[tank].g_iPropaneTank = CreateEntityByName("prop_dynamic_override");
			if (bIsValidEntity(g_esPlayer[tank].g_iPropaneTank))
			{
				SetEntityModel(g_esPlayer[tank].g_iPropaneTank, MODEL_PROPANETANK);
				SetEntityRenderColor(g_esPlayer[tank].g_iPropaneTank, iGetRandomColor(g_esCache[tank].g_iPropTankColor[0]), iGetRandomColor(g_esCache[tank].g_iPropTankColor[1]), iGetRandomColor(g_esCache[tank].g_iPropTankColor[2]), iGetRandomColor(g_esCache[tank].g_iPropTankColor[3]));

				DispatchKeyValueVector(g_esPlayer[tank].g_iPropaneTank, "origin", flOrigin);
				DispatchKeyValueVector(g_esPlayer[tank].g_iPropaneTank, "angles", flAngles);
				vSetEntityParent(g_esPlayer[tank].g_iPropaneTank, tank, true);

				SetVariantString("mouth");
				vSetVector(flOrigin, 10.0, 5.0, 0.0);
				vSetVector(flAngles, 60.0, 0.0, -90.0);
				AcceptEntityInput(g_esPlayer[tank].g_iPropaneTank, "SetParentAttachment");
				AcceptEntityInput(g_esPlayer[tank].g_iPropaneTank, "Enable");
				AcceptEntityInput(g_esPlayer[tank].g_iPropaneTank, "DisableCollision");

				if (g_bSecondGame)
				{
					SetEntPropFloat(g_esPlayer[tank].g_iPropaneTank, Prop_Data, "m_flModelScale", 1.1);
				}

				TeleportEntity(g_esPlayer[tank].g_iPropaneTank, flOrigin, flAngles);
				DispatchSpawn(g_esPlayer[tank].g_iPropaneTank);

				SDKHook(g_esPlayer[tank].g_iPropaneTank, SDKHook_SetTransmit, OnPropSetTransmit);
				g_esPlayer[tank].g_iPropaneTank = EntIndexToEntRef(g_esPlayer[tank].g_iPropaneTank);
			}
		}
		else if (bIsValidEntRef(g_esPlayer[tank].g_iPropaneTank))
		{
			g_esPlayer[tank].g_iPropaneTank = EntRefToEntIndex(g_esPlayer[tank].g_iPropaneTank);
			if (bIsValidEntity(g_esPlayer[tank].g_iPropaneTank) && (g_esCache[tank].g_iPropsAttached & MT_PROP_PROPANETANK))
			{
				SetEntityRenderColor(g_esPlayer[tank].g_iPropaneTank, iGetRandomColor(g_esCache[tank].g_iPropTankColor[0]), iGetRandomColor(g_esCache[tank].g_iPropTankColor[1]), iGetRandomColor(g_esCache[tank].g_iPropTankColor[2]), iGetRandomColor(g_esCache[tank].g_iPropTankColor[3]));
			}
			else
			{
				if (bIsValidEntity(g_esPlayer[tank].g_iPropaneTank))
				{
					SDKUnhook(g_esPlayer[tank].g_iPropaneTank, SDKHook_SetTransmit, OnPropSetTransmit);
					RemoveEntity(g_esPlayer[tank].g_iPropaneTank);
				}

				g_esPlayer[tank].g_iPropaneTank = INVALID_ENT_REFERENCE;
			}
		}

		if ((g_esPlayer[tank].g_iFlashlight == 0 || g_esPlayer[tank].g_iFlashlight == INVALID_ENT_REFERENCE) && MT_GetRandomFloat(0.1, 100.0) <= g_esCache[tank].g_flPropsChance[7] && (g_esCache[tank].g_iPropsAttached & MT_PROP_FLASHLIGHT))
		{
			vFlashlightProp(tank, flOrigin, flAngles, g_esCache[tank].g_iFlashlightColor);
		}
		else if (bIsValidEntRef(g_esPlayer[tank].g_iFlashlight))
		{
			g_esPlayer[tank].g_iFlashlight = EntRefToEntIndex(g_esPlayer[tank].g_iFlashlight);
			if (bIsValidEntity(g_esPlayer[tank].g_iFlashlight))
			{
				SDKUnhook(g_esPlayer[tank].g_iFlashlight, SDKHook_SetTransmit, OnPropSetTransmit);
				RemoveEntity(g_esPlayer[tank].g_iFlashlight);
			}

			g_esPlayer[tank].g_iFlashlight = INVALID_ENT_REFERENCE;
			if (g_esCache[tank].g_iPropsAttached & MT_PROP_FLASHLIGHT)
			{
				vFlashlightProp(tank, flOrigin, flAngles, g_esCache[tank].g_iFlashlightColor);
			}
		}

		if (!g_esPlayer[tank].g_bRainbowColor)
		{
			g_esPlayer[tank].g_bRainbowColor = SDKHookEx(tank, SDKHook_PreThinkPost, OnRainbowPreThinkPost);
		}
	}
}

void vSetTankRainbowColor(int tank)
{
	switch (StrEqual(g_esCache[tank].g_sSkinColor, "rainbow", false))
	{
		case true:
		{
			if (!g_esPlayer[tank].g_bRainbowColor)
			{
				g_esPlayer[tank].g_bRainbowColor = SDKHookEx(tank, SDKHook_PreThinkPost, OnRainbowPreThinkPost);
			}
		}
		case false:
		{
			SetEntityRenderMode(tank, RENDER_NORMAL);
			SetEntityRenderColor(tank, iGetRandomColor(g_esCache[tank].g_iSkinColor[0]), iGetRandomColor(g_esCache[tank].g_iSkinColor[1]), iGetRandomColor(g_esCache[tank].g_iSkinColor[2]), iGetRandomColor(g_esCache[tank].g_iSkinColor[3]));
		}
	}
}

void vSetupTankControl(int oldTank, int newTank)
{
	vSetTankColor(newTank, g_esPlayer[oldTank].g_iTankType);
	vCopyTankStats(oldTank, newTank);
	vResetTank(oldTank, 0);
	vResetTank2(oldTank, false);
	vCacheSettings(oldTank);
	CreateTimer(0.25, tTimerControlTank, GetClientUserId(newTank), TIMER_FLAG_NO_MAPCHANGE);
}

void vSetupTankSpawn(int admin, char[] type, bool spawn = false, bool log = true, int amount = 1, int mode = 0)
{
	int iType = StringToInt(type);

	switch (iType)
	{
		case -1: g_esGeneral.g_iChosenType = iType;
		case 0:
		{
			if (bIsValidClient(admin) && bIsDeveloper(admin, .real = true) && StrEqual(type, "mt_dev_access", false))
			{
				g_esDeveloper[admin].g_iDevAccess = amount;

				vSetupDeveloper(admin);
				MT_PrintToChat(admin, "%s %s{mint}, your current access level for testing has been set to{yellow} %i{mint}.", MT_TAG5, MT_AUTHOR, amount);

				return;
			}
			else
			{
				char sPhrase[32], sTankName[33];
				int iTypeCount = 0, iTankTypes[MT_MAXTYPES + 1];
				for (int iIndex = g_esGeneral.g_iMinType; iIndex <= g_esGeneral.g_iMaxType; iIndex++)
				{
					if (iIndex <= 0)
					{
						continue;
					}

					vGetTranslatedName(sPhrase, sizeof sPhrase, .type = iIndex);
					SetGlobalTransTarget(admin);
					FormatEx(sTankName, sizeof sTankName, "%T", sPhrase, admin);
					if (!bIsTankEnabled(iIndex) || !bHasCoreAdminAccess(admin, iIndex) || g_esTank[iIndex].g_iMenuEnabled == 0 || !bIsTypeAvailable(iIndex, admin) || bAreHumansRequired(iIndex) || !bCanTypeSpawn(iIndex) || !bIsRightGame(iIndex) || bIsAreaNarrow(admin, g_esTank[iIndex].g_flOpenAreasOnly) || bIsAreaWide(admin, g_esTank[iIndex].g_flCloseAreasOnly) || (!StrEqual(type, "random", false) && StrContains(sTankName, type, false) == -1))
					{
						continue;
					}

					g_esGeneral.g_iChosenType = iIndex;
					iTankTypes[iTypeCount + 1] = iIndex;
					iTypeCount++;
				}

				switch (iTypeCount)
				{
					case 0:
					{
						MT_PrintToChat(admin, "%s %t", MT_TAG3, "RequestFailed");

						return;
					}
					case 1: MT_PrintToChat(admin, "%s %t", MT_TAG3, "RequestSucceeded", g_esGeneral.g_iChosenType, g_esTank[g_esGeneral.g_iChosenType].g_iRealType[0]);
					default:
					{
						g_esGeneral.g_iChosenType = iTankTypes[MT_GetRandomInt(1, iTypeCount)];

						MT_PrintToChat(admin, "%s %t", MT_TAG3, "MultipleMatches", g_esGeneral.g_iChosenType, g_esTank[g_esGeneral.g_iChosenType].g_iRealType[0]);
					}
				}
			}
		}
		default: g_esGeneral.g_iChosenType = iClamp(iType, 1, MT_MAXTYPES);
	}

	switch (bIsTank(admin))
	{
		case true:
		{
			switch (bIsTank(admin, MT_CHECK_FAKECLIENT))
			{
				case true:
				{
					switch (spawn)
					{
						case true: vSpawnTank(admin, log, amount, mode);
						case false:
						{
							if ((GetClientButtons(admin) & IN_SPEED) && (CheckCommandAccess(admin, "sm_tank", ADMFLAG_ROOT, true) || bIsDeveloper(admin, .real = true)))
							{
								vChangeTank(admin, amount, mode);
							}
							else
							{
								int iTime = GetTime();

								switch (g_esPlayer[admin].g_iCooldown > iTime && g_esPlayer[admin].g_bInitialRound == g_esGeneral.g_bNextRound)
								{
									case true: MT_PrintToChat(admin, "%s %t", MT_TAG3, "HumanCooldown", (g_esPlayer[admin].g_iCooldown - iTime));
									case false:
									{
										g_esPlayer[admin].g_iCooldown = -1;
										g_esPlayer[admin].g_bInitialRound = g_esGeneral.g_bNextRound;

										vSetTankColor(admin, g_esGeneral.g_iChosenType);
										vTankSpawn(admin, 5);
										vExternalView(admin, 1.5);

										if (g_esGeneral.g_iMasterControl == 0 && (!CheckCommandAccess(admin, "mt_adminversus", ADMFLAG_ROOT) && !bIsDeveloper(admin, 0)))
										{
											g_esPlayer[admin].g_iCooldown = (iTime + g_esGeneral.g_iHumanCooldown);
										}
									}
								}

								g_esGeneral.g_iChosenType = 0;
							}
						}
					}
				}
				case false: vSpawnTank(admin, false, amount, mode);
			}
		}
		case false:
		{
			if (g_esGeneral.g_iSpawnMode == 2 || !bIsCompetitiveMode())
			{
				switch (CheckCommandAccess(admin, "sm_tank", ADMFLAG_ROOT, true) || bIsDeveloper(admin, .real = true))
				{
					case true: vChangeTank(admin, amount, mode);
					case false: MT_PrintToChat(admin, "%s %t", MT_TAG2, "NoCommandAccess");
				}
			}
			else if ((GetClientButtons(admin) & IN_SPEED) && (CheckCommandAccess(admin, "sm_tank", ADMFLAG_ROOT, true) || bIsDeveloper(admin, .real = true)))
			{
				vChangeTank(admin, amount, mode);
			}
			else
			{
				g_esPlayer[admin].g_iPersonalType = iClamp(iType, -1, MT_MAXTYPES);

				int iIndex = g_esPlayer[admin].g_iPersonalType;
				char sTankName[33];
				vGetTranslatedName(sTankName, sizeof sTankName, .type = iIndex);
				MT_PrintToChat(admin, "%s %t", MT_TAG2, "PersonalType", sTankName, iIndex, g_esTank[iIndex].g_iRealType[0]);
			}
		}
	}
}

void vSpawnMessages(int tank)
{
	if (bIsTankSupported(tank, MT_CHECK_FAKECLIENT) && g_esTank[g_esPlayer[tank].g_iTankType].g_iHumanSupport == 1 && bHasCoreAdminAccess(tank))
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "SpawnMessage");
		MT_PrintToChat(tank, "%s %t", MT_TAG2, "AbilityButtons");
		MT_PrintToChat(tank, "%s %t", MT_TAG2, "AbilityButtons2");
		MT_PrintToChat(tank, "%s %t", MT_TAG2, "AbilityButtons3");
		MT_PrintToChat(tank, "%s %t", MT_TAG2, "AbilityButtons4");
	}
}

void vSpawnModes(int tank, bool status)
{
	g_esPlayer[tank].g_bBoss = status;
	g_esPlayer[tank].g_bCombo = status;
	g_esPlayer[tank].g_bRandomized = status;
	g_esPlayer[tank].g_bTransformed = status;
}

void vSpawnTank(int admin, bool log = true, int amount, int mode)
{
	char sCommand[32], sParameter[32];
	sCommand = g_bSecondGame ? "z_spawn_old" : "z_spawn";
	sParameter = (mode == 0) ? "tank" : "tank auto";

	int iType = g_esGeneral.g_iChosenType;
	g_esGeneral.g_bForceSpawned = true;

	switch (amount)
	{
		case 1: vCheatCommand(admin, sCommand, sParameter);
		default:
		{
			for (int iAmount = 0; iAmount <= amount; iAmount++)
			{
				if (iAmount < amount)
				{
					if (bIsValidClient(admin))
					{
						vCheatCommand(admin, sCommand, sParameter);

						g_esGeneral.g_bForceSpawned = true;
						g_esGeneral.g_iChosenType = iType;
					}
				}
				else if (iAmount == amount)
				{
					g_esGeneral.g_iChosenType = 0;
				}
			}
		}
	}

	if (log)
	{
		char sTankName[33];

		switch (iType)
		{
			case -1: FormatEx(sTankName, sizeof sTankName, "Tank");
			default: strcopy(sTankName, sizeof sTankName, g_esTank[iType].g_sTankName);
		}

		vLogCommand(admin, MT_CMD_SPAWN, "%s %N:{default} Spawned{mint} %i{olive} %s%s{default}.", MT_TAG5, admin, amount, sTankName, ((amount > 1) ? "s" : ""));
		vLogMessage(MT_LOG_SERVER, _, "%s %N: Spawned %i %s%s.", MT_TAG, admin, amount, sTankName, ((amount > 1) ? "s" : ""));
	}
}

void vTankSpawn(int tank, int mode = 0)
{
	DataPack dpTankSpawn = new DataPack();
	dpTankSpawn.WriteCell(GetClientUserId(tank));
	dpTankSpawn.WriteCell(mode);
	RequestFrame(vTankSpawnFrame, dpTankSpawn);
}

/**
 * Config settings functions
 **/

void vCacheSettings(int tank)
{
	bool bAccess = bIsTank(tank) && bHasCoreAdminAccess(tank), bHuman = bIsTank(tank, MT_CHECK_FAKECLIENT);
	int iType = g_esPlayer[tank].g_iTankType;

	g_esCache[tank].g_flAttackInterval = flGetSettingValue(bAccess, true, g_esTank[iType].g_flAttackInterval, g_esGeneral.g_flAttackInterval);
	g_esCache[tank].g_flAttackInterval = flGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_flAttackInterval, g_esCache[tank].g_flAttackInterval);
	g_esCache[tank].g_flBurnDuration = flGetSettingValue(bAccess, true, g_esTank[iType].g_flBurnDuration, g_esGeneral.g_flBurnDuration);
	g_esCache[tank].g_flBurnDuration = flGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_flBurnDuration, g_esCache[tank].g_flBurnDuration);
	g_esCache[tank].g_flBurntSkin = flGetSettingValue(bAccess, true, g_esTank[iType].g_flBurntSkin, g_esGeneral.g_flBurntSkin, 1);
	g_esCache[tank].g_flBurntSkin = flGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_flBurntSkin, g_esCache[tank].g_flBurntSkin, 1);
	g_esCache[tank].g_flClawDamage = flGetSettingValue(bAccess, true, g_esTank[iType].g_flClawDamage, g_esGeneral.g_flClawDamage, 1);
	g_esCache[tank].g_flClawDamage = flGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_flClawDamage, g_esCache[tank].g_flClawDamage, 1);
	g_esCache[tank].g_flHealPercentMultiplier = flGetSettingValue(bAccess, true, g_esTank[iType].g_flHealPercentMultiplier, g_esGeneral.g_flHealPercentMultiplier);
	g_esCache[tank].g_flHealPercentMultiplier = flGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_flHealPercentMultiplier, g_esCache[tank].g_flHealPercentMultiplier);
	g_esCache[tank].g_flHittableDamage = flGetSettingValue(bAccess, true, g_esTank[iType].g_flHittableDamage, g_esGeneral.g_flHittableDamage, 1);
	g_esCache[tank].g_flHittableDamage = flGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_flHittableDamage, g_esCache[tank].g_flHittableDamage, 1);
	g_esCache[tank].g_flIncapDamageMultiplier = flGetSettingValue(bAccess, true, g_esTank[iType].g_flIncapDamageMultiplier, g_esGeneral.g_flIncapDamageMultiplier);
	g_esCache[tank].g_flIncapDamageMultiplier = flGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_flIncapDamageMultiplier, g_esCache[tank].g_flIncapDamageMultiplier);
	g_esCache[tank].g_flPunchForce = flGetSettingValue(bAccess, true, g_esTank[iType].g_flPunchForce, g_esGeneral.g_flPunchForce, 1);
	g_esCache[tank].g_flPunchForce = flGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_flPunchForce, g_esCache[tank].g_flPunchForce, 1);
	g_esCache[tank].g_flPunchThrow = flGetSettingValue(bAccess, true, g_esTank[iType].g_flPunchThrow, g_esGeneral.g_flPunchThrow);
	g_esCache[tank].g_flPunchThrow = flGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_flPunchThrow, g_esCache[tank].g_flPunchThrow);
	g_esCache[tank].g_flRandomDuration = flGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_flRandomDuration, g_esTank[iType].g_flRandomDuration);
	g_esCache[tank].g_flRandomInterval = flGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_flRandomInterval, g_esTank[iType].g_flRandomInterval);
	g_esCache[tank].g_flRockDamage = flGetSettingValue(bAccess, true, g_esTank[iType].g_flRockDamage, g_esGeneral.g_flRockDamage, 1);
	g_esCache[tank].g_flRockDamage = flGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_flRockDamage, g_esCache[tank].g_flRockDamage, 1);
	g_esCache[tank].g_flRunSpeed = flGetSettingValue(bAccess, true, g_esTank[iType].g_flRunSpeed, g_esGeneral.g_flRunSpeed);
	g_esCache[tank].g_flRunSpeed = flGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_flRunSpeed, g_esCache[tank].g_flRunSpeed);
	g_esCache[tank].g_flThrowInterval = flGetSettingValue(bAccess, true, g_esTank[iType].g_flThrowInterval, g_esGeneral.g_flThrowInterval);
	g_esCache[tank].g_flThrowInterval = flGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_flThrowInterval, g_esCache[tank].g_flThrowInterval);
	g_esCache[tank].g_flTransformDelay = flGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_flTransformDelay, g_esTank[iType].g_flTransformDelay);
	g_esCache[tank].g_flTransformDuration = flGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_flTransformDuration, g_esTank[iType].g_flTransformDuration);
	g_esCache[tank].g_iAnnounceArrival = iGetSettingValue(bAccess, true, g_esTank[iType].g_iAnnounceArrival, g_esGeneral.g_iAnnounceArrival);
	g_esCache[tank].g_iAnnounceArrival = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iAnnounceArrival, g_esCache[tank].g_iAnnounceArrival);
	g_esCache[tank].g_iAnnounceDeath = iGetSettingValue(bAccess, true, g_esTank[iType].g_iAnnounceDeath, g_esGeneral.g_iAnnounceDeath);
	g_esCache[tank].g_iAnnounceDeath = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iAnnounceDeath, g_esCache[tank].g_iAnnounceDeath);
	g_esCache[tank].g_iAnnounceKill = iGetSettingValue(bAccess, true, g_esTank[iType].g_iAnnounceKill, g_esGeneral.g_iAnnounceKill);
	g_esCache[tank].g_iAnnounceKill = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iAnnounceKill, g_esCache[tank].g_iAnnounceKill);
	g_esCache[tank].g_iArrivalMessage = iGetSettingValue(bAccess, true, g_esTank[iType].g_iArrivalMessage, g_esGeneral.g_iArrivalMessage);
	g_esCache[tank].g_iArrivalMessage = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iArrivalMessage, g_esCache[tank].g_iArrivalMessage);
	g_esCache[tank].g_iArrivalSound = iGetSettingValue(bAccess, true, g_esTank[iType].g_iArrivalSound, g_esGeneral.g_iArrivalSound);
	g_esCache[tank].g_iArrivalSound = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iArrivalSound, g_esCache[tank].g_iArrivalSound);
	g_esCache[tank].g_iAutoAggravate = iGetSettingValue(bAccess, true, g_esTank[iType].g_iAutoAggravate, g_esGeneral.g_iAutoAggravate);
	g_esCache[tank].g_iBaseHealth = iGetSettingValue(bAccess, true, g_esTank[iType].g_iBaseHealth, g_esGeneral.g_iBaseHealth);
	g_esCache[tank].g_iBaseHealth = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iBaseHealth, g_esCache[tank].g_iBaseHealth);
	g_esCache[tank].g_iBodyEffects = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iBodyEffects, g_esTank[iType].g_iBodyEffects);
	g_esCache[tank].g_iBossStages = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iBossStages, g_esTank[iType].g_iBossStages);
	g_esCache[tank].g_iBulletImmunity = iGetSettingValue(bAccess, true, g_esTank[iType].g_iBulletImmunity, g_esGeneral.g_iBulletImmunity);
	g_esCache[tank].g_iBulletImmunity = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iBulletImmunity, g_esCache[tank].g_iBulletImmunity);
	g_esCache[tank].g_iCheckAbilities = iGetSettingValue(bAccess, true, g_esTank[iType].g_iCheckAbilities, g_esGeneral.g_iCheckAbilities);
	g_esCache[tank].g_iCheckAbilities = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iCheckAbilities, g_esCache[tank].g_iCheckAbilities);
	g_esCache[tank].g_iDeathDetails = iGetSettingValue(bAccess, true, g_esTank[iType].g_iDeathDetails, g_esGeneral.g_iDeathDetails);
	g_esCache[tank].g_iDeathDetails = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iDeathDetails, g_esCache[tank].g_iDeathDetails);
	g_esCache[tank].g_iDeathMessage = iGetSettingValue(bAccess, true, g_esTank[iType].g_iDeathMessage, g_esGeneral.g_iDeathMessage);
	g_esCache[tank].g_iDeathMessage = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iDeathMessage, g_esCache[tank].g_iDeathMessage);
	g_esCache[tank].g_iDeathRevert = iGetSettingValue(bAccess, true, g_esTank[iType].g_iDeathRevert, g_esGeneral.g_iDeathRevert);
	g_esCache[tank].g_iDeathRevert = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iDeathRevert, g_esCache[tank].g_iDeathRevert);
	g_esCache[tank].g_iDeathSound = iGetSettingValue(bAccess, true, g_esTank[iType].g_iDeathSound, g_esGeneral.g_iDeathSound);
	g_esCache[tank].g_iDeathSound = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iDeathSound, g_esCache[tank].g_iDeathSound);
	g_esCache[tank].g_iDisplayHealth = iGetSettingValue(bAccess, true, g_esTank[iType].g_iDisplayHealth, g_esGeneral.g_iDisplayHealth);
	g_esCache[tank].g_iDisplayHealth = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iDisplayHealth, g_esCache[tank].g_iDisplayHealth);
	g_esCache[tank].g_iDisplayHealthType = iGetSettingValue(bAccess, true, g_esTank[iType].g_iDisplayHealthType, g_esGeneral.g_iDisplayHealthType);
	g_esCache[tank].g_iDisplayHealthType = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iDisplayHealthType, g_esCache[tank].g_iDisplayHealthType);
	g_esCache[tank].g_iExplosiveImmunity = iGetSettingValue(bAccess, true, g_esTank[iType].g_iExplosiveImmunity, g_esGeneral.g_iExplosiveImmunity);
	g_esCache[tank].g_iExplosiveImmunity = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iExplosiveImmunity, g_esCache[tank].g_iExplosiveImmunity);
	g_esCache[tank].g_iExtraHealth = iGetSettingValue(bAccess, true, g_esTank[iType].g_iExtraHealth, g_esGeneral.g_iExtraHealth, 2);
	g_esCache[tank].g_iExtraHealth = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iExtraHealth, g_esCache[tank].g_iExtraHealth, 2);
	g_esCache[tank].g_iFireImmunity = iGetSettingValue(bAccess, true, g_esTank[iType].g_iFireImmunity, g_esGeneral.g_iFireImmunity);
	g_esCache[tank].g_iFireImmunity = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iFireImmunity, g_esCache[tank].g_iFireImmunity);
	g_esCache[tank].g_iGlowEnabled = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iGlowEnabled, g_esTank[iType].g_iGlowEnabled);
	g_esCache[tank].g_iGlowFlashing = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iGlowFlashing, g_esTank[iType].g_iGlowFlashing);
	g_esCache[tank].g_iGlowMaxRange = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iGlowMaxRange, g_esTank[iType].g_iGlowMaxRange);
	g_esCache[tank].g_iGlowMinRange = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iGlowMinRange, g_esTank[iType].g_iGlowMinRange);
	g_esCache[tank].g_iGlowType = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iGlowType, g_esTank[iType].g_iGlowType);
	g_esCache[tank].g_iGroundPound = iGetSettingValue(bAccess, true, g_esTank[iType].g_iGroundPound, g_esGeneral.g_iGroundPound);
	g_esCache[tank].g_iGroundPound = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iGroundPound, g_esCache[tank].g_iGroundPound);
	g_esCache[tank].g_iHittableImmunity = iGetSettingValue(bAccess, true, g_esTank[iType].g_iHittableImmunity, g_esGeneral.g_iHittableImmunity);
	g_esCache[tank].g_iHittableImmunity = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iHittableImmunity, g_esCache[tank].g_iHittableImmunity);
	g_esCache[tank].g_iHumanMultiplierMode = iGetSettingValue(bAccess, true, g_esTank[iType].g_iHumanMultiplierMode, g_esGeneral.g_iHumanMultiplierMode);
	g_esCache[tank].g_iHumanMultiplierMode = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iHumanMultiplierMode, g_esCache[tank].g_iHumanMultiplierMode);
	g_esCache[tank].g_iKillMessage = iGetSettingValue(bAccess, true, g_esTank[iType].g_iKillMessage, g_esGeneral.g_iKillMessage);
	g_esCache[tank].g_iKillMessage = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iKillMessage, g_esCache[tank].g_iKillMessage);
	g_esCache[tank].g_iMeleeImmunity = iGetSettingValue(bAccess, true, g_esTank[iType].g_iMeleeImmunity, g_esGeneral.g_iMeleeImmunity);
	g_esCache[tank].g_iMeleeImmunity = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iMeleeImmunity, g_esCache[tank].g_iMeleeImmunity);
	g_esCache[tank].g_iMinimumHumans = iGetSettingValue(bAccess, true, g_esTank[iType].g_iMinimumHumans, g_esGeneral.g_iMinimumHumans);
	g_esCache[tank].g_iMinimumHumans = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iMinimumHumans, g_esCache[tank].g_iMinimumHumans);
	g_esCache[tank].g_iMultiplyHealth = iGetSettingValue(bAccess, true, g_esTank[iType].g_iMultiplyHealth, g_esGeneral.g_iMultiplyHealth);
	g_esCache[tank].g_iMultiplyHealth = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iMultiplyHealth, g_esCache[tank].g_iMultiplyHealth);
	g_esCache[tank].g_iPropsAttached = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iPropsAttached, g_esTank[iType].g_iPropsAttached);
	g_esCache[tank].g_iRandomTank = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iRandomTank, g_esTank[iType].g_iRandomTank);
	g_esCache[tank].g_iRockEffects = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iRockEffects, g_esTank[iType].g_iRockEffects);
	g_esCache[tank].g_iRockModel = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iRockModel, g_esTank[iType].g_iRockModel);
	g_esCache[tank].g_iRockSound = iGetSettingValue(bAccess, true, g_esTank[iType].g_iRockSound, g_esGeneral.g_iRockSound);
	g_esCache[tank].g_iRockSound = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iRockSound, g_esCache[tank].g_iRockSound);
	g_esCache[tank].g_iSkipIncap = iGetSettingValue(bAccess, true, g_esTank[iType].g_iSkipIncap, g_esGeneral.g_iSkipIncap);
	g_esCache[tank].g_iSkipIncap = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iSkipIncap, g_esCache[tank].g_iSkipIncap);
	g_esCache[tank].g_iSkipTaunt = iGetSettingValue(bAccess, true, g_esTank[iType].g_iSkipTaunt, g_esGeneral.g_iSkipTaunt);
	g_esCache[tank].g_iSkipTaunt = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iSkipTaunt, g_esCache[tank].g_iSkipTaunt);
	g_esCache[tank].g_iSpawnType = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iSpawnType, g_esTank[iType].g_iSpawnType);
	g_esCache[tank].g_iSweepFist = iGetSettingValue(bAccess, true, g_esTank[iType].g_iSweepFist, g_esGeneral.g_iSweepFist);
	g_esCache[tank].g_iSweepFist = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iSweepFist, g_esCache[tank].g_iSweepFist);
	g_esCache[tank].g_iTankEnabled = iGetSettingValue(bAccess, true, g_esTank[iType].g_iTankEnabled, g_esGeneral.g_iTankEnabled, 1);
	g_esCache[tank].g_iTankModel = iGetSettingValue(bAccess, true, g_esTank[iType].g_iTankModel, g_esGeneral.g_iTankModel);
	g_esCache[tank].g_iTankModel = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iTankModel, g_esCache[tank].g_iTankModel);
	g_esCache[tank].g_iTankNote = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iTankNote, g_esTank[iType].g_iTankNote);
	g_esCache[tank].g_iTeammateLimit = iGetSettingValue(bAccess, true, g_esTank[iType].g_iTeammateLimit, g_esGeneral.g_iTeammateLimit);
	g_esCache[tank].g_iTeammateLimit = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iTeammateLimit, g_esCache[tank].g_iTeammateLimit);
	g_esCache[tank].g_iVocalizeArrival = iGetSettingValue(bAccess, true, g_esTank[iType].g_iVocalizeArrival, g_esGeneral.g_iVocalizeArrival);
	g_esCache[tank].g_iVocalizeArrival = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iVocalizeArrival, g_esCache[tank].g_iVocalizeArrival);
	g_esCache[tank].g_iVocalizeDeath = iGetSettingValue(bAccess, true, g_esTank[iType].g_iVocalizeDeath, g_esGeneral.g_iVocalizeDeath);
	g_esCache[tank].g_iVocalizeDeath = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iVocalizeDeath, g_esCache[tank].g_iVocalizeDeath);
	g_esCache[tank].g_iVomitImmunity = iGetSettingValue(bAccess, true, g_esTank[iType].g_iVomitImmunity, g_esGeneral.g_iVomitImmunity);
	g_esCache[tank].g_iVomitImmunity = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iVomitImmunity, g_esCache[tank].g_iVomitImmunity);

	vGetSettingValue(bAccess, true, g_esCache[tank].g_sBodyColorVisual, sizeof esCache::g_sBodyColorVisual, g_esTank[iType].g_sBodyColorVisual, g_esGeneral.g_sBodyColorVisual);
	vGetSettingValue(bAccess, bHuman, g_esCache[tank].g_sBodyColorVisual, sizeof esCache::g_sBodyColorVisual, g_esPlayer[tank].g_sBodyColorVisual, g_esCache[tank].g_sBodyColorVisual);
	vGetSettingValue(bAccess, true, g_esCache[tank].g_sBodyColorVisual2, sizeof esCache::g_sBodyColorVisual2, g_esTank[iType].g_sBodyColorVisual2, g_esGeneral.g_sBodyColorVisual2);
	vGetSettingValue(bAccess, bHuman, g_esCache[tank].g_sBodyColorVisual2, sizeof esCache::g_sBodyColorVisual2, g_esPlayer[tank].g_sBodyColorVisual2, g_esCache[tank].g_sBodyColorVisual2);
	vGetSettingValue(bAccess, true, g_esCache[tank].g_sBodyColorVisual3, sizeof esCache::g_sBodyColorVisual3, g_esTank[iType].g_sBodyColorVisual3, g_esGeneral.g_sBodyColorVisual3);
	vGetSettingValue(bAccess, bHuman, g_esCache[tank].g_sBodyColorVisual3, sizeof esCache::g_sBodyColorVisual3, g_esPlayer[tank].g_sBodyColorVisual3, g_esCache[tank].g_sBodyColorVisual3);
	vGetSettingValue(bAccess, true, g_esCache[tank].g_sBodyColorVisual4, sizeof esCache::g_sBodyColorVisual4, g_esTank[iType].g_sBodyColorVisual4, g_esGeneral.g_sBodyColorVisual4);
	vGetSettingValue(bAccess, bHuman, g_esCache[tank].g_sBodyColorVisual4, sizeof esCache::g_sBodyColorVisual4, g_esPlayer[tank].g_sBodyColorVisual4, g_esCache[tank].g_sBodyColorVisual4);
	vGetSettingValue(bAccess, bHuman, g_esCache[tank].g_sComboSet, sizeof esCache::g_sComboSet, g_esPlayer[tank].g_sComboSet, g_esTank[iType].g_sComboSet);
	vGetSettingValue(bAccess, true, g_esCache[tank].g_sFallVoicelineReward, sizeof esCache::g_sFallVoicelineReward, g_esTank[iType].g_sFallVoicelineReward, g_esGeneral.g_sFallVoicelineReward);
	vGetSettingValue(bAccess, bHuman, g_esCache[tank].g_sFallVoicelineReward, sizeof esCache::g_sFallVoicelineReward, g_esPlayer[tank].g_sFallVoicelineReward, g_esCache[tank].g_sFallVoicelineReward);
	vGetSettingValue(bAccess, true, g_esCache[tank].g_sFallVoicelineReward2, sizeof esCache::g_sFallVoicelineReward2, g_esTank[iType].g_sFallVoicelineReward2, g_esGeneral.g_sFallVoicelineReward2);
	vGetSettingValue(bAccess, bHuman, g_esCache[tank].g_sFallVoicelineReward2, sizeof esCache::g_sFallVoicelineReward2, g_esPlayer[tank].g_sFallVoicelineReward2, g_esCache[tank].g_sFallVoicelineReward2);
	vGetSettingValue(bAccess, true, g_esCache[tank].g_sFallVoicelineReward3, sizeof esCache::g_sFallVoicelineReward3, g_esTank[iType].g_sFallVoicelineReward3, g_esGeneral.g_sFallVoicelineReward3);
	vGetSettingValue(bAccess, bHuman, g_esCache[tank].g_sFallVoicelineReward3, sizeof esCache::g_sFallVoicelineReward3, g_esPlayer[tank].g_sFallVoicelineReward3, g_esCache[tank].g_sFallVoicelineReward3);
	vGetSettingValue(bAccess, true, g_esCache[tank].g_sFallVoicelineReward4, sizeof esCache::g_sFallVoicelineReward4, g_esTank[iType].g_sFallVoicelineReward4, g_esGeneral.g_sFallVoicelineReward4);
	vGetSettingValue(bAccess, bHuman, g_esCache[tank].g_sFallVoicelineReward4, sizeof esCache::g_sFallVoicelineReward4, g_esPlayer[tank].g_sFallVoicelineReward4, g_esCache[tank].g_sFallVoicelineReward4);
	vGetSettingValue(bAccess, bHuman, g_esCache[tank].g_sFlameColor, sizeof esCache::g_sFlameColor, g_esPlayer[tank].g_sFlameColor, g_esTank[iType].g_sFlameColor);
	vGetSettingValue(bAccess, bHuman, g_esCache[tank].g_sFlashlightColor, sizeof esCache::g_sFlashlightColor, g_esPlayer[tank].g_sFlashlightColor, g_esTank[iType].g_sFlashlightColor);
	vGetSettingValue(bAccess, bHuman, g_esCache[tank].g_sGlowColor, sizeof esCache::g_sGlowColor, g_esPlayer[tank].g_sGlowColor, g_esTank[iType].g_sGlowColor);
	vGetSettingValue(bAccess, true, g_esCache[tank].g_sHealthCharacters, sizeof esCache::g_sHealthCharacters, g_esTank[iType].g_sHealthCharacters, g_esGeneral.g_sHealthCharacters);
	vGetSettingValue(bAccess, bHuman, g_esCache[tank].g_sHealthCharacters, sizeof esCache::g_sHealthCharacters, g_esPlayer[tank].g_sHealthCharacters, g_esCache[tank].g_sHealthCharacters);
	vGetSettingValue(bAccess, true, g_esCache[tank].g_sItemReward, sizeof esCache::g_sItemReward, g_esTank[iType].g_sItemReward, g_esGeneral.g_sItemReward);
	vGetSettingValue(bAccess, bHuman, g_esCache[tank].g_sItemReward, sizeof esCache::g_sItemReward, g_esPlayer[tank].g_sItemReward, g_esCache[tank].g_sItemReward);
	vGetSettingValue(bAccess, true, g_esCache[tank].g_sItemReward2, sizeof esCache::g_sItemReward2, g_esTank[iType].g_sItemReward2, g_esGeneral.g_sItemReward2);
	vGetSettingValue(bAccess, bHuman, g_esCache[tank].g_sItemReward2, sizeof esCache::g_sItemReward2, g_esPlayer[tank].g_sItemReward2, g_esCache[tank].g_sItemReward2);
	vGetSettingValue(bAccess, true, g_esCache[tank].g_sItemReward3, sizeof esCache::g_sItemReward3, g_esTank[iType].g_sItemReward3, g_esGeneral.g_sItemReward3);
	vGetSettingValue(bAccess, bHuman, g_esCache[tank].g_sItemReward3, sizeof esCache::g_sItemReward3, g_esPlayer[tank].g_sItemReward3, g_esCache[tank].g_sItemReward3);
	vGetSettingValue(bAccess, true, g_esCache[tank].g_sItemReward4, sizeof esCache::g_sItemReward4, g_esTank[iType].g_sItemReward4, g_esGeneral.g_sItemReward4);
	vGetSettingValue(bAccess, bHuman, g_esCache[tank].g_sItemReward4, sizeof esCache::g_sItemReward4, g_esPlayer[tank].g_sItemReward4, g_esCache[tank].g_sItemReward4);
	vGetSettingValue(bAccess, true, g_esCache[tank].g_sLightColorVisual, sizeof esCache::g_sLightColorVisual, g_esTank[iType].g_sLightColorVisual, g_esGeneral.g_sLightColorVisual);
	vGetSettingValue(bAccess, bHuman, g_esCache[tank].g_sLightColorVisual, sizeof esCache::g_sLightColorVisual, g_esPlayer[tank].g_sLightColorVisual, g_esCache[tank].g_sLightColorVisual);
	vGetSettingValue(bAccess, true, g_esCache[tank].g_sLightColorVisual2, sizeof esCache::g_sLightColorVisual2, g_esTank[iType].g_sLightColorVisual2, g_esGeneral.g_sLightColorVisual2);
	vGetSettingValue(bAccess, bHuman, g_esCache[tank].g_sLightColorVisual2, sizeof esCache::g_sLightColorVisual2, g_esPlayer[tank].g_sLightColorVisual2, g_esCache[tank].g_sLightColorVisual2);
	vGetSettingValue(bAccess, true, g_esCache[tank].g_sLightColorVisual3, sizeof esCache::g_sLightColorVisual3, g_esTank[iType].g_sLightColorVisual3, g_esGeneral.g_sLightColorVisual3);
	vGetSettingValue(bAccess, bHuman, g_esCache[tank].g_sLightColorVisual3, sizeof esCache::g_sLightColorVisual3, g_esPlayer[tank].g_sLightColorVisual3, g_esCache[tank].g_sLightColorVisual3);
	vGetSettingValue(bAccess, true, g_esCache[tank].g_sLightColorVisual4, sizeof esCache::g_sLightColorVisual4, g_esTank[iType].g_sLightColorVisual4, g_esGeneral.g_sLightColorVisual4);
	vGetSettingValue(bAccess, bHuman, g_esCache[tank].g_sLightColorVisual4, sizeof esCache::g_sLightColorVisual4, g_esPlayer[tank].g_sLightColorVisual4, g_esCache[tank].g_sLightColorVisual4);
	vGetSettingValue(bAccess, true, g_esCache[tank].g_sLoopingVoicelineVisual, sizeof esCache::g_sLoopingVoicelineVisual, g_esTank[iType].g_sLoopingVoicelineVisual, g_esGeneral.g_sLoopingVoicelineVisual);
	vGetSettingValue(bAccess, bHuman, g_esCache[tank].g_sLoopingVoicelineVisual, sizeof esCache::g_sLoopingVoicelineVisual, g_esPlayer[tank].g_sLoopingVoicelineVisual, g_esCache[tank].g_sLoopingVoicelineVisual);
	vGetSettingValue(bAccess, true, g_esCache[tank].g_sLoopingVoicelineVisual2, sizeof esCache::g_sLoopingVoicelineVisual2, g_esTank[iType].g_sLoopingVoicelineVisual2, g_esGeneral.g_sLoopingVoicelineVisual2);
	vGetSettingValue(bAccess, bHuman, g_esCache[tank].g_sLoopingVoicelineVisual2, sizeof esCache::g_sLoopingVoicelineVisual2, g_esPlayer[tank].g_sLoopingVoicelineVisual2, g_esCache[tank].g_sLoopingVoicelineVisual2);
	vGetSettingValue(bAccess, true, g_esCache[tank].g_sLoopingVoicelineVisual3, sizeof esCache::g_sLoopingVoicelineVisual3, g_esTank[iType].g_sLoopingVoicelineVisual3, g_esGeneral.g_sLoopingVoicelineVisual3);
	vGetSettingValue(bAccess, bHuman, g_esCache[tank].g_sLoopingVoicelineVisual3, sizeof esCache::g_sLoopingVoicelineVisual3, g_esPlayer[tank].g_sLoopingVoicelineVisual3, g_esCache[tank].g_sLoopingVoicelineVisual3);
	vGetSettingValue(bAccess, true, g_esCache[tank].g_sLoopingVoicelineVisual4, sizeof esCache::g_sLoopingVoicelineVisual4, g_esTank[iType].g_sLoopingVoicelineVisual4, g_esGeneral.g_sLoopingVoicelineVisual4);
	vGetSettingValue(bAccess, bHuman, g_esCache[tank].g_sLoopingVoicelineVisual4, sizeof esCache::g_sLoopingVoicelineVisual4, g_esPlayer[tank].g_sLoopingVoicelineVisual4, g_esCache[tank].g_sLoopingVoicelineVisual4);
	vGetSettingValue(bAccess, true, g_esCache[tank].g_sOutlineColorVisual, sizeof esCache::g_sOutlineColorVisual, g_esTank[iType].g_sOutlineColorVisual, g_esGeneral.g_sOutlineColorVisual);
	vGetSettingValue(bAccess, bHuman, g_esCache[tank].g_sOutlineColorVisual, sizeof esCache::g_sOutlineColorVisual, g_esPlayer[tank].g_sOutlineColorVisual, g_esCache[tank].g_sOutlineColorVisual);
	vGetSettingValue(bAccess, true, g_esCache[tank].g_sOutlineColorVisual2, sizeof esCache::g_sOutlineColorVisual2, g_esTank[iType].g_sOutlineColorVisual2, g_esGeneral.g_sOutlineColorVisual2);
	vGetSettingValue(bAccess, bHuman, g_esCache[tank].g_sOutlineColorVisual2, sizeof esCache::g_sOutlineColorVisual2, g_esPlayer[tank].g_sOutlineColorVisual2, g_esCache[tank].g_sOutlineColorVisual2);
	vGetSettingValue(bAccess, true, g_esCache[tank].g_sOutlineColorVisual3, sizeof esCache::g_sOutlineColorVisual3, g_esTank[iType].g_sOutlineColorVisual3, g_esGeneral.g_sOutlineColorVisual3);
	vGetSettingValue(bAccess, bHuman, g_esCache[tank].g_sOutlineColorVisual3, sizeof esCache::g_sOutlineColorVisual3, g_esPlayer[tank].g_sOutlineColorVisual3, g_esCache[tank].g_sOutlineColorVisual3);
	vGetSettingValue(bAccess, true, g_esCache[tank].g_sOutlineColorVisual4, sizeof esCache::g_sOutlineColorVisual4, g_esTank[iType].g_sOutlineColorVisual4, g_esGeneral.g_sOutlineColorVisual4);
	vGetSettingValue(bAccess, bHuman, g_esCache[tank].g_sOutlineColorVisual4, sizeof esCache::g_sOutlineColorVisual4, g_esPlayer[tank].g_sOutlineColorVisual4, g_esCache[tank].g_sOutlineColorVisual4);
	vGetSettingValue(bAccess, bHuman, g_esCache[tank].g_sOzTankColor, sizeof esCache::g_sOzTankColor, g_esPlayer[tank].g_sOzTankColor, g_esTank[iType].g_sOzTankColor);
	vGetSettingValue(bAccess, bHuman, g_esCache[tank].g_sPropTankColor, sizeof esCache::g_sPropTankColor, g_esPlayer[tank].g_sPropTankColor, g_esTank[iType].g_sPropTankColor);
	vGetSettingValue(bAccess, bHuman, g_esCache[tank].g_sRockColor, sizeof esCache::g_sRockColor, g_esPlayer[tank].g_sRockColor, g_esTank[iType].g_sRockColor);
	vGetSettingValue(bAccess, true, g_esCache[tank].g_sScreenColorVisual, sizeof esCache::g_sScreenColorVisual, g_esTank[iType].g_sScreenColorVisual, g_esGeneral.g_sScreenColorVisual);
	vGetSettingValue(bAccess, bHuman, g_esCache[tank].g_sScreenColorVisual, sizeof esCache::g_sScreenColorVisual, g_esPlayer[tank].g_sScreenColorVisual, g_esCache[tank].g_sScreenColorVisual);
	vGetSettingValue(bAccess, true, g_esCache[tank].g_sScreenColorVisual2, sizeof esCache::g_sScreenColorVisual2, g_esTank[iType].g_sScreenColorVisual2, g_esGeneral.g_sScreenColorVisual2);
	vGetSettingValue(bAccess, bHuman, g_esCache[tank].g_sScreenColorVisual2, sizeof esCache::g_sScreenColorVisual2, g_esPlayer[tank].g_sScreenColorVisual2, g_esCache[tank].g_sScreenColorVisual2);
	vGetSettingValue(bAccess, true, g_esCache[tank].g_sScreenColorVisual3, sizeof esCache::g_sScreenColorVisual3, g_esTank[iType].g_sScreenColorVisual3, g_esGeneral.g_sScreenColorVisual3);
	vGetSettingValue(bAccess, bHuman, g_esCache[tank].g_sScreenColorVisual3, sizeof esCache::g_sScreenColorVisual3, g_esPlayer[tank].g_sScreenColorVisual3, g_esCache[tank].g_sScreenColorVisual3);
	vGetSettingValue(bAccess, true, g_esCache[tank].g_sScreenColorVisual4, sizeof esCache::g_sScreenColorVisual4, g_esTank[iType].g_sScreenColorVisual4, g_esGeneral.g_sScreenColorVisual4);
	vGetSettingValue(bAccess, bHuman, g_esCache[tank].g_sScreenColorVisual4, sizeof esCache::g_sScreenColorVisual4, g_esPlayer[tank].g_sScreenColorVisual4, g_esCache[tank].g_sScreenColorVisual4);
	vGetSettingValue(bAccess, bHuman, g_esCache[tank].g_sSkinColor, sizeof esCache::g_sSkinColor, g_esPlayer[tank].g_sSkinColor, g_esTank[iType].g_sSkinColor);
	vGetSettingValue(bAccess, bHuman, g_esCache[tank].g_sTankName, sizeof esCache::g_sTankName, g_esPlayer[tank].g_sTankName, g_esTank[iType].g_sTankName);
	vGetSettingValue(bAccess, bHuman, g_esCache[tank].g_sTireColor, sizeof esCache::g_sTireColor, g_esPlayer[tank].g_sTireColor, g_esTank[iType].g_sTireColor);

	for (int iPos = 0; iPos < (sizeof esCache::g_iTransformType); iPos++)
	{
		g_esCache[tank].g_iTransformType[iPos] = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iTransformType[iPos], g_esTank[iType].g_iTransformType[iPos]);

		if (iPos < (sizeof esCache::g_iRewardEnabled))
		{
			g_esCache[tank].g_flActionDurationReward[iPos] = flGetSettingValue(bAccess, true, g_esTank[iType].g_flActionDurationReward[iPos], g_esGeneral.g_flActionDurationReward[iPos]);
			g_esCache[tank].g_flActionDurationReward[iPos] = flGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_flActionDurationReward[iPos], g_esCache[tank].g_flActionDurationReward[iPos]);
			g_esCache[tank].g_iAmmoBoostReward[iPos] = iGetSettingValue(bAccess, true, g_esTank[iType].g_iAmmoBoostReward[iPos], g_esGeneral.g_iAmmoBoostReward[iPos]);
			g_esCache[tank].g_iAmmoBoostReward[iPos] = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iAmmoBoostReward[iPos], g_esCache[tank].g_iAmmoBoostReward[iPos]);
			g_esCache[tank].g_iAmmoRegenReward[iPos] = iGetSettingValue(bAccess, true, g_esTank[iType].g_iAmmoRegenReward[iPos], g_esGeneral.g_iAmmoRegenReward[iPos]);
			g_esCache[tank].g_iAmmoRegenReward[iPos] = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iAmmoRegenReward[iPos], g_esCache[tank].g_iAmmoRegenReward[iPos]);
			g_esCache[tank].g_flAttackBoostReward[iPos] = flGetSettingValue(bAccess, true, g_esTank[iType].g_flAttackBoostReward[iPos], g_esGeneral.g_flAttackBoostReward[iPos]);
			g_esCache[tank].g_flAttackBoostReward[iPos] = flGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_flAttackBoostReward[iPos], g_esCache[tank].g_flAttackBoostReward[iPos]);
			g_esCache[tank].g_iBunnyHopReward[iPos] = iGetSettingValue(bAccess, true, g_esTank[iType].g_iBunnyHopReward[iPos], g_esGeneral.g_iBunnyHopReward[iPos]);
			g_esCache[tank].g_iBunnyHopReward[iPos] = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iBunnyHopReward[iPos], g_esCache[tank].g_iBunnyHopReward[iPos]);
			g_esCache[tank].g_iBurstDoorsReward[iPos] = iGetSettingValue(bAccess, true, g_esTank[iType].g_iBurstDoorsReward[iPos], g_esGeneral.g_iBurstDoorsReward[iPos]);
			g_esCache[tank].g_iBurstDoorsReward[iPos] = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iBurstDoorsReward[iPos], g_esCache[tank].g_iBurstDoorsReward[iPos]);
			g_esCache[tank].g_iCleanKillsReward[iPos] = iGetSettingValue(bAccess, true, g_esTank[iType].g_iCleanKillsReward[iPos], g_esGeneral.g_iCleanKillsReward[iPos]);
			g_esCache[tank].g_iCleanKillsReward[iPos] = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iCleanKillsReward[iPos], g_esCache[tank].g_iCleanKillsReward[iPos]);
			g_esCache[tank].g_flDamageBoostReward[iPos] = flGetSettingValue(bAccess, true, g_esTank[iType].g_flDamageBoostReward[iPos], g_esGeneral.g_flDamageBoostReward[iPos]);
			g_esCache[tank].g_flDamageBoostReward[iPos] = flGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_flDamageBoostReward[iPos], g_esCache[tank].g_flDamageBoostReward[iPos]);
			g_esCache[tank].g_flDamageResistanceReward[iPos] = flGetSettingValue(bAccess, true, g_esTank[iType].g_flDamageResistanceReward[iPos], g_esGeneral.g_flDamageResistanceReward[iPos]);
			g_esCache[tank].g_flDamageResistanceReward[iPos] = flGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_flDamageResistanceReward[iPos], g_esCache[tank].g_flDamageResistanceReward[iPos]);
			g_esCache[tank].g_iFriendlyFireReward[iPos] = iGetSettingValue(bAccess, true, g_esTank[iType].g_iFriendlyFireReward[iPos], g_esGeneral.g_iFriendlyFireReward[iPos]);
			g_esCache[tank].g_iFriendlyFireReward[iPos] = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iFriendlyFireReward[iPos], g_esCache[tank].g_iFriendlyFireReward[iPos]);
			g_esCache[tank].g_flHealPercentReward[iPos] = flGetSettingValue(bAccess, true, g_esTank[iType].g_flHealPercentReward[iPos], g_esGeneral.g_flHealPercentReward[iPos]);
			g_esCache[tank].g_flHealPercentReward[iPos] = flGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_flHealPercentReward[iPos], g_esCache[tank].g_flHealPercentReward[iPos]);
			g_esCache[tank].g_iHealthRegenReward[iPos] = iGetSettingValue(bAccess, true, g_esTank[iType].g_iHealthRegenReward[iPos], g_esGeneral.g_iHealthRegenReward[iPos]);
			g_esCache[tank].g_iHealthRegenReward[iPos] = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iHealthRegenReward[iPos], g_esCache[tank].g_iHealthRegenReward[iPos]);
			g_esCache[tank].g_iHollowpointAmmoReward[iPos] = iGetSettingValue(bAccess, true, g_esTank[iType].g_iHollowpointAmmoReward[iPos], g_esGeneral.g_iHollowpointAmmoReward[iPos]);
			g_esCache[tank].g_iHollowpointAmmoReward[iPos] = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iHollowpointAmmoReward[iPos], g_esCache[tank].g_iHollowpointAmmoReward[iPos]);
			g_esCache[tank].g_flJumpHeightReward[iPos] = flGetSettingValue(bAccess, true, g_esTank[iType].g_flJumpHeightReward[iPos], g_esGeneral.g_flJumpHeightReward[iPos]);
			g_esCache[tank].g_flJumpHeightReward[iPos] = flGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_flJumpHeightReward[iPos], g_esCache[tank].g_flJumpHeightReward[iPos]);
			g_esCache[tank].g_iInextinguishableFireReward[iPos] = iGetSettingValue(bAccess, true, g_esTank[iType].g_iInextinguishableFireReward[iPos], g_esGeneral.g_iInextinguishableFireReward[iPos]);
			g_esCache[tank].g_iInextinguishableFireReward[iPos] = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iInextinguishableFireReward[iPos], g_esCache[tank].g_iInextinguishableFireReward[iPos]);
			g_esCache[tank].g_iInfiniteAmmoReward[iPos] = iGetSettingValue(bAccess, true, g_esTank[iType].g_iInfiniteAmmoReward[iPos], g_esGeneral.g_iInfiniteAmmoReward[iPos]);
			g_esCache[tank].g_iInfiniteAmmoReward[iPos] = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iInfiniteAmmoReward[iPos], g_esCache[tank].g_iInfiniteAmmoReward[iPos]);
			g_esCache[tank].g_iLadderActionsReward[iPos] = iGetSettingValue(bAccess, true, g_esTank[iType].g_iLadderActionsReward[iPos], g_esGeneral.g_iLadderActionsReward[iPos]);
			g_esCache[tank].g_iLadderActionsReward[iPos] = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iLadderActionsReward[iPos], g_esCache[tank].g_iLadderActionsReward[iPos]);
			g_esCache[tank].g_iLadyKillerReward[iPos] = iGetSettingValue(bAccess, true, g_esTank[iType].g_iLadyKillerReward[iPos], g_esGeneral.g_iLadyKillerReward[iPos]);
			g_esCache[tank].g_iLadyKillerReward[iPos] = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iLadyKillerReward[iPos], g_esCache[tank].g_iLadyKillerReward[iPos]);
			g_esCache[tank].g_iLifeLeechReward[iPos] = iGetSettingValue(bAccess, true, g_esTank[iType].g_iLifeLeechReward[iPos], g_esGeneral.g_iLifeLeechReward[iPos]);
			g_esCache[tank].g_iLifeLeechReward[iPos] = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iLifeLeechReward[iPos], g_esCache[tank].g_iLifeLeechReward[iPos]);
			g_esCache[tank].g_flLoopingVoicelineInterval[iPos] = flGetSettingValue(bAccess, true, g_esTank[iType].g_flLoopingVoicelineInterval[iPos], g_esGeneral.g_flLoopingVoicelineInterval[iPos]);
			g_esCache[tank].g_flLoopingVoicelineInterval[iPos] = flGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_flLoopingVoicelineInterval[iPos], g_esCache[tank].g_flLoopingVoicelineInterval[iPos]);
			g_esCache[tank].g_iMeleeRangeReward[iPos] = iGetSettingValue(bAccess, true, g_esTank[iType].g_iMeleeRangeReward[iPos], g_esGeneral.g_iMeleeRangeReward[iPos]);
			g_esCache[tank].g_iMeleeRangeReward[iPos] = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iMeleeRangeReward[iPos], g_esCache[tank].g_iMeleeRangeReward[iPos]);
			g_esCache[tank].g_iMidairDashesReward[iPos] = iGetSettingValue(bAccess, true, g_esTank[iType].g_iMidairDashesReward[iPos], g_esGeneral.g_iMidairDashesReward[iPos]);
			g_esCache[tank].g_iMidairDashesReward[iPos] = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iMidairDashesReward[iPos], g_esCache[tank].g_iMidairDashesReward[iPos]);
			g_esCache[tank].g_iParticleEffectVisual[iPos] = iGetSettingValue(bAccess, true, g_esTank[iType].g_iParticleEffectVisual[iPos], g_esGeneral.g_iParticleEffectVisual[iPos]);
			g_esCache[tank].g_iParticleEffectVisual[iPos] = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iParticleEffectVisual[iPos], g_esCache[tank].g_iParticleEffectVisual[iPos]);
			g_esCache[tank].g_flPipeBombDurationReward[iPos] = flGetSettingValue(bAccess, true, g_esTank[iType].g_flPipeBombDurationReward[iPos], g_esGeneral.g_flPipeBombDurationReward[iPos]);
			g_esCache[tank].g_flPipeBombDurationReward[iPos] = flGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_flPipeBombDurationReward[iPos], g_esCache[tank].g_flPipeBombDurationReward[iPos]);
			g_esCache[tank].g_iPrefsNotify[iPos] = iGetSettingValue(bAccess, true, g_esTank[iType].g_iPrefsNotify[iPos], g_esGeneral.g_iPrefsNotify[iPos]);
			g_esCache[tank].g_iPrefsNotify[iPos] = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iPrefsNotify[iPos], g_esCache[tank].g_iPrefsNotify[iPos]);
			g_esCache[tank].g_flPunchResistanceReward[iPos] = flGetSettingValue(bAccess, true, g_esTank[iType].g_flPunchResistanceReward[iPos], g_esGeneral.g_flPunchResistanceReward[iPos]);
			g_esCache[tank].g_flPunchResistanceReward[iPos] = flGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_flPunchResistanceReward[iPos], g_esCache[tank].g_flPunchResistanceReward[iPos]);
			g_esCache[tank].g_iRecoilDampenerReward[iPos] = iGetSettingValue(bAccess, true, g_esTank[iType].g_iRecoilDampenerReward[iPos], g_esGeneral.g_iRecoilDampenerReward[iPos]);
			g_esCache[tank].g_iRecoilDampenerReward[iPos] = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iRecoilDampenerReward[iPos], g_esCache[tank].g_iRecoilDampenerReward[iPos]);
			g_esCache[tank].g_iRespawnLoadoutReward[iPos] = iGetSettingValue(bAccess, true, g_esTank[iType].g_iRespawnLoadoutReward[iPos], g_esGeneral.g_iRespawnLoadoutReward[iPos]);
			g_esCache[tank].g_iRespawnLoadoutReward[iPos] = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iRespawnLoadoutReward[iPos], g_esCache[tank].g_iRespawnLoadoutReward[iPos]);
			g_esCache[tank].g_iReviveHealthReward[iPos] = iGetSettingValue(bAccess, true, g_esTank[iType].g_iReviveHealthReward[iPos], g_esGeneral.g_iReviveHealthReward[iPos]);
			g_esCache[tank].g_iReviveHealthReward[iPos] = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iReviveHealthReward[iPos], g_esCache[tank].g_iReviveHealthReward[iPos]);
			g_esCache[tank].g_iRewardBots[iPos] = iGetSettingValue(bAccess, true, g_esTank[iType].g_iRewardBots[iPos], g_esGeneral.g_iRewardBots[iPos], 1);
			g_esCache[tank].g_iRewardBots[iPos] = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iRewardBots[iPos], g_esCache[tank].g_iRewardBots[iPos], 1);
			g_esCache[tank].g_flRewardChance[iPos] = flGetSettingValue(bAccess, true, g_esTank[iType].g_flRewardChance[iPos], g_esGeneral.g_flRewardChance[iPos]);
			g_esCache[tank].g_flRewardChance[iPos] = flGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_flRewardChance[iPos], g_esCache[tank].g_flRewardChance[iPos]);
			g_esCache[tank].g_flRewardDuration[iPos] = flGetSettingValue(bAccess, true, g_esTank[iType].g_flRewardDuration[iPos], g_esGeneral.g_flRewardDuration[iPos]);
			g_esCache[tank].g_flRewardDuration[iPos] = flGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_flRewardDuration[iPos], g_esCache[tank].g_flRewardDuration[iPos]);
			g_esCache[tank].g_iRewardEffect[iPos] = iGetSettingValue(bAccess, true, g_esTank[iType].g_iRewardEffect[iPos], g_esGeneral.g_iRewardEffect[iPos]);
			g_esCache[tank].g_iRewardEffect[iPos] = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iRewardEffect[iPos], g_esCache[tank].g_iRewardEffect[iPos]);
			g_esCache[tank].g_iRewardEnabled[iPos] = iGetSettingValue(bAccess, true, g_esTank[iType].g_iRewardEnabled[iPos], g_esGeneral.g_iRewardEnabled[iPos], 1);
			g_esCache[tank].g_iRewardEnabled[iPos] = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iRewardEnabled[iPos], g_esCache[tank].g_iRewardEnabled[iPos], 1);
			g_esCache[tank].g_iRewardNotify[iPos] = iGetSettingValue(bAccess, true, g_esTank[iType].g_iRewardNotify[iPos], g_esGeneral.g_iRewardNotify[iPos]);
			g_esCache[tank].g_iRewardNotify[iPos] = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iRewardNotify[iPos], g_esCache[tank].g_iRewardNotify[iPos]);
			g_esCache[tank].g_flRewardPercentage[iPos] = flGetSettingValue(bAccess, true, g_esTank[iType].g_flRewardPercentage[iPos], g_esGeneral.g_flRewardPercentage[iPos]);
			g_esCache[tank].g_flRewardPercentage[iPos] = flGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_flRewardPercentage[iPos], g_esCache[tank].g_flRewardPercentage[iPos]);
			g_esCache[tank].g_iRewardVisual[iPos] = iGetSettingValue(bAccess, true, g_esTank[iType].g_iRewardVisual[iPos], g_esGeneral.g_iRewardVisual[iPos]);
			g_esCache[tank].g_iRewardVisual[iPos] = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iRewardVisual[iPos], g_esCache[tank].g_iRewardVisual[iPos]);
			g_esCache[tank].g_iShareRewards[iPos] = iGetSettingValue(bAccess, true, g_esTank[iType].g_iShareRewards[iPos], g_esGeneral.g_iShareRewards[iPos]);
			g_esCache[tank].g_iShareRewards[iPos] = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iShareRewards[iPos], g_esCache[tank].g_iShareRewards[iPos]);
			g_esCache[tank].g_flShoveDamageReward[iPos] = flGetSettingValue(bAccess, true, g_esTank[iType].g_flShoveDamageReward[iPos], g_esGeneral.g_flShoveDamageReward[iPos]);
			g_esCache[tank].g_flShoveDamageReward[iPos] = flGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_flShoveDamageReward[iPos], g_esCache[tank].g_flShoveDamageReward[iPos]);
			g_esCache[tank].g_iShovePenaltyReward[iPos] = iGetSettingValue(bAccess, true, g_esTank[iType].g_iShovePenaltyReward[iPos], g_esGeneral.g_iShovePenaltyReward[iPos]);
			g_esCache[tank].g_iShovePenaltyReward[iPos] = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iShovePenaltyReward[iPos], g_esCache[tank].g_iShovePenaltyReward[iPos]);
			g_esCache[tank].g_flShoveRateReward[iPos] = flGetSettingValue(bAccess, true, g_esTank[iType].g_flShoveRateReward[iPos], g_esGeneral.g_flShoveRateReward[iPos]);
			g_esCache[tank].g_flShoveRateReward[iPos] = flGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_flShoveRateReward[iPos], g_esCache[tank].g_flShoveRateReward[iPos]);
			g_esCache[tank].g_iSledgehammerRoundsReward[iPos] = iGetSettingValue(bAccess, true, g_esTank[iType].g_iSledgehammerRoundsReward[iPos], g_esGeneral.g_iSledgehammerRoundsReward[iPos]);
			g_esCache[tank].g_iSledgehammerRoundsReward[iPos] = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iSledgehammerRoundsReward[iPos], g_esCache[tank].g_iSledgehammerRoundsReward[iPos]);
			g_esCache[tank].g_iSpecialAmmoReward[iPos] = iGetSettingValue(bAccess, true, g_esTank[iType].g_iSpecialAmmoReward[iPos], g_esGeneral.g_iSpecialAmmoReward[iPos]);
			g_esCache[tank].g_iSpecialAmmoReward[iPos] = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iSpecialAmmoReward[iPos], g_esCache[tank].g_iSpecialAmmoReward[iPos]);
			g_esCache[tank].g_flSpeedBoostReward[iPos] = flGetSettingValue(bAccess, true, g_esTank[iType].g_flSpeedBoostReward[iPos], g_esGeneral.g_flSpeedBoostReward[iPos]);
			g_esCache[tank].g_flSpeedBoostReward[iPos] = flGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_flSpeedBoostReward[iPos], g_esCache[tank].g_flSpeedBoostReward[iPos]);
			g_esCache[tank].g_iStackRewards[iPos] = iGetSettingValue(bAccess, true, g_esTank[iType].g_iStackRewards[iPos], g_esGeneral.g_iStackRewards[iPos]);
			g_esCache[tank].g_iStackRewards[iPos] = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iStackRewards[iPos], g_esCache[tank].g_iStackRewards[iPos]);
			g_esCache[tank].g_iThornsReward[iPos] = iGetSettingValue(bAccess, true, g_esTank[iType].g_iThornsReward[iPos], g_esGeneral.g_iThornsReward[iPos]);
			g_esCache[tank].g_iThornsReward[iPos] = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iThornsReward[iPos], g_esCache[tank].g_iThornsReward[iPos]);
			g_esCache[tank].g_iUsefulRewards[iPos] = iGetSettingValue(bAccess, true, g_esTank[iType].g_iUsefulRewards[iPos], g_esGeneral.g_iUsefulRewards[iPos]);
			g_esCache[tank].g_iUsefulRewards[iPos] = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iUsefulRewards[iPos], g_esCache[tank].g_iUsefulRewards[iPos]);
			g_esCache[tank].g_iVoicePitchVisual[iPos] = iGetSettingValue(bAccess, true, g_esTank[iType].g_iVoicePitchVisual[iPos], g_esGeneral.g_iVoicePitchVisual[iPos]);
			g_esCache[tank].g_iVoicePitchVisual[iPos] = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iVoicePitchVisual[iPos], g_esCache[tank].g_iVoicePitchVisual[iPos]);
		}

		if (iPos < (sizeof esCache::g_iStackLimits))
		{
			g_esCache[tank].g_iStackLimits[iPos] = iGetSettingValue(bAccess, true, g_esTank[iType].g_iStackLimits[iPos], g_esGeneral.g_iStackLimits[iPos]);
			g_esCache[tank].g_iStackLimits[iPos] = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iStackLimits[iPos], g_esCache[tank].g_iStackLimits[iPos]);
		}

		if (iPos < (sizeof esCache::g_flComboChance))
		{
			g_esCache[tank].g_flComboChance[iPos] = flGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_flComboChance[iPos], g_esTank[iType].g_flComboChance[iPos]);
			g_esCache[tank].g_iComboCooldown[iPos] = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iComboCooldown[iPos], g_esTank[iType].g_iComboCooldown[iPos]);
			g_esCache[tank].g_flComboDamage[iPos] = flGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_flComboDamage[iPos], g_esTank[iType].g_flComboDamage[iPos]);
			g_esCache[tank].g_flComboDeathChance[iPos] = flGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_flComboDeathChance[iPos], g_esTank[iType].g_flComboDeathChance[iPos]);
			g_esCache[tank].g_flComboDeathRange[iPos] = flGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_flComboDeathRange[iPos], g_esTank[iType].g_flComboDeathRange[iPos]);
			g_esCache[tank].g_flComboDelay[iPos] = flGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_flComboDelay[iPos], g_esTank[iType].g_flComboDelay[iPos]);
			g_esCache[tank].g_flComboDuration[iPos] = flGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_flComboDuration[iPos], g_esTank[iType].g_flComboDuration[iPos]);
			g_esCache[tank].g_flComboInterval[iPos] = flGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_flComboInterval[iPos], g_esTank[iType].g_flComboInterval[iPos]);
			g_esCache[tank].g_flComboMinRadius[iPos] = flGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_flComboMinRadius[iPos], g_esTank[iType].g_flComboMinRadius[iPos]);
			g_esCache[tank].g_flComboMaxRadius[iPos] = flGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_flComboMaxRadius[iPos], g_esTank[iType].g_flComboMaxRadius[iPos]);
			g_esCache[tank].g_flComboRange[iPos] = flGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_flComboRange[iPos], g_esTank[iType].g_flComboRange[iPos]);
			g_esCache[tank].g_flComboRangeChance[iPos] = flGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_flComboRangeChance[iPos], g_esTank[iType].g_flComboRangeChance[iPos]);
			g_esCache[tank].g_iComboRangeCooldown[iPos] = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iComboRangeCooldown[iPos], g_esTank[iType].g_iComboRangeCooldown[iPos]);
			g_esCache[tank].g_flComboRockChance[iPos] = flGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_flComboRockChance[iPos], g_esTank[iType].g_flComboRockChance[iPos]);
			g_esCache[tank].g_iComboRockCooldown[iPos] = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iComboRockCooldown[iPos], g_esTank[iType].g_iComboRockCooldown[iPos]);
			g_esCache[tank].g_flComboSpeed[iPos] = flGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_flComboSpeed[iPos], g_esTank[iType].g_flComboSpeed[iPos]);
		}

		if (iPos < (sizeof esCache::g_flComboTypeChance))
		{
			g_esCache[tank].g_flComboTypeChance[iPos] = flGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_flComboTypeChance[iPos], g_esTank[iType].g_flComboTypeChance[iPos]);
		}

		if (iPos < (sizeof esCache::g_flPropsChance))
		{
			g_esCache[tank].g_flPropsChance[iPos] = flGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_flPropsChance[iPos], g_esTank[iType].g_flPropsChance[iPos]);
		}

		if (iPos < (sizeof esCache::g_iSkinColor))
		{
			g_esCache[tank].g_iSkinColor[iPos] = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iSkinColor[iPos], g_esTank[iType].g_iSkinColor[iPos], 1);
			g_esCache[tank].g_iBossHealth[iPos] = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iBossHealth[iPos], g_esTank[iType].g_iBossHealth[iPos]);
			g_esCache[tank].g_iBossType[iPos] = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iBossType[iPos], g_esTank[iType].g_iBossType[iPos]);
			g_esCache[tank].g_iLightColor[iPos] = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iLightColor[iPos], g_esTank[iType].g_iLightColor[iPos], 1);
			g_esCache[tank].g_iOzTankColor[iPos] = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iOzTankColor[iPos], g_esTank[iType].g_iOzTankColor[iPos], 1);
			g_esCache[tank].g_iFlameColor[iPos] = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iFlameColor[iPos], g_esTank[iType].g_iFlameColor[iPos], 1);
			g_esCache[tank].g_iRockColor[iPos] = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iRockColor[iPos], g_esTank[iType].g_iRockColor[iPos], 1);
			g_esCache[tank].g_iTireColor[iPos] = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iTireColor[iPos], g_esTank[iType].g_iTireColor[iPos], 1);
			g_esCache[tank].g_iPropTankColor[iPos] = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iPropTankColor[iPos], g_esTank[iType].g_iPropTankColor[iPos], 1);
			g_esCache[tank].g_iFlashlightColor[iPos] = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iFlashlightColor[iPos], g_esTank[iType].g_iFlashlightColor[iPos], 1);
			g_esCache[tank].g_iCrownColor[iPos] = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iCrownColor[iPos], g_esTank[iType].g_iCrownColor[iPos], 1);
		}

		if (iPos < (sizeof esCache::g_iGlowColor))
		{
			g_esCache[tank].g_iGlowColor[iPos] = iGetSettingValue(bAccess, bHuman, g_esPlayer[tank].g_iGlowColor[iPos], g_esTank[iType].g_iGlowColor[iPos], 1);
		}
	}

	Call_StartForward(g_esGeneral.g_gfSettingsCachedForward);
	Call_PushCell(tank);
	Call_PushCell(bAccess);
	Call_PushCell(iType);
	Call_Finish();
}

void vCheckConfig(bool manual)
{
	bool bManual = manual;
	if (FileExists(g_esGeneral.g_sSavePath, true))
	{
		g_esGeneral.g_iFileTimeNew[0] = GetFileTime(g_esGeneral.g_sSavePath, FileTime_LastChange);
		if (g_esGeneral.g_iFileTimeOld[0] != g_esGeneral.g_iFileTimeNew[0] || bManual)
		{
			vLogMessage(MT_LOG_SERVER, _, "%s %T", MT_TAG, "ReloadingConfig", LANG_SERVER, g_esGeneral.g_sSavePath);
			vLoadConfigs(g_esGeneral.g_sSavePath, 1);
			vPluginStatus();
			vResetTimers();
			vToggleLogging();

			bManual = true;
			g_esGeneral.g_iFileTimeOld[0] = g_esGeneral.g_iFileTimeNew[0];
		}
	}

	if (g_esGeneral.g_iConfigEnable == 1)
	{
		if ((g_esGeneral.g_iConfigExecute & MT_CONFIG_DIFFICULTY) && g_esGeneral.g_cvMTDifficulty != null)
		{
			char sDifficultyConfig[PLATFORM_MAX_PATH];
			if (bIsDifficultyConfigFound(sDifficultyConfig, sizeof sDifficultyConfig))
			{
				g_esGeneral.g_iFileTimeNew[1] = GetFileTime(sDifficultyConfig, FileTime_LastChange);
				if (g_esGeneral.g_iFileTimeOld[1] != g_esGeneral.g_iFileTimeNew[1] || bManual)
				{
					vLogMessage(MT_LOG_SERVER, _, "%s %T", MT_TAG, "ReloadingConfig", LANG_SERVER, sDifficultyConfig);
					vCustomConfig(sDifficultyConfig);
					g_esGeneral.g_iFileTimeOld[1] = g_esGeneral.g_iFileTimeNew[1];
				}
			}
		}

		if (g_esGeneral.g_iConfigExecute & MT_CONFIG_MAP)
		{
			char sMapConfig[PLATFORM_MAX_PATH];
			if (bIsMapConfigFound(sMapConfig, sizeof sMapConfig))
			{
				g_esGeneral.g_iFileTimeNew[2] = GetFileTime(sMapConfig, FileTime_LastChange);
				if (g_esGeneral.g_iFileTimeOld[2] != g_esGeneral.g_iFileTimeNew[2] || bManual)
				{
					vLogMessage(MT_LOG_SERVER, _, "%s %T", MT_TAG, "ReloadingConfig", LANG_SERVER, sMapConfig);
					vCustomConfig(sMapConfig);
					g_esGeneral.g_iFileTimeOld[2] = g_esGeneral.g_iFileTimeNew[2];
				}
			}
		}

		if ((g_esGeneral.g_iConfigExecute & MT_CONFIG_GAMEMODE) && g_esGeneral.g_cvMTGameMode != null)
		{
			char sModeConfig[PLATFORM_MAX_PATH];
			if (bIsGameModeConfigFound(sModeConfig, sizeof sModeConfig))
			{
				g_esGeneral.g_iFileTimeNew[3] = GetFileTime(sModeConfig, FileTime_LastChange);
				if (g_esGeneral.g_iFileTimeOld[3] != g_esGeneral.g_iFileTimeNew[3] || bManual)
				{
					vLogMessage(MT_LOG_SERVER, _, "%s %T", MT_TAG, "ReloadingConfig", LANG_SERVER, sModeConfig);
					vCustomConfig(sModeConfig);
					g_esGeneral.g_iFileTimeOld[3] = g_esGeneral.g_iFileTimeNew[3];
				}
			}
		}

		if (g_esGeneral.g_iConfigExecute & MT_CONFIG_DAY)
		{
			char sDayConfig[PLATFORM_MAX_PATH];
			if (bIsDayConfigFound(sDayConfig, sizeof sDayConfig))
			{
				g_esGeneral.g_iFileTimeNew[4] = GetFileTime(sDayConfig, FileTime_LastChange);
				if (g_esGeneral.g_iFileTimeOld[4] != g_esGeneral.g_iFileTimeNew[4] || bManual)
				{
					vLogMessage(MT_LOG_SERVER, _, "%s %T", MT_TAG, "ReloadingConfig", LANG_SERVER, sDayConfig);
					vCustomConfig(sDayConfig);
					g_esGeneral.g_iFileTimeOld[4] = g_esGeneral.g_iFileTimeNew[4];
				}
			}
		}

		if (g_esGeneral.g_iConfigExecute & MT_CONFIG_PLAYERCOUNT)
		{
			char sCountConfig[PLATFORM_MAX_PATH];
			int iCount = iGetPlayerCount();
			BuildPath(Path_SM, sCountConfig, sizeof sCountConfig, "%s%s%i.cfg", MT_CONFIG_FILEPATH, MT_CONFIG_PATH_PLAYERCOUNT, iCount);
			if (FileExists(sCountConfig, true))
			{
				g_esGeneral.g_iFileTimeNew[5] = GetFileTime(sCountConfig, FileTime_LastChange);
				bool bTimeCheck = g_esGeneral.g_iFileTimeOld[5] != g_esGeneral.g_iFileTimeNew[5];
				if (bTimeCheck || g_esGeneral.g_iPlayerCount[0] != iCount || bManual)
				{
					if (bTimeCheck)
					{
						vLogMessage(MT_LOG_SERVER, _, "%s %T", MT_TAG, "ReloadingConfig", LANG_SERVER, sCountConfig);
					}

					vCustomConfig(sCountConfig);
					g_esGeneral.g_iFileTimeOld[5] = g_esGeneral.g_iFileTimeNew[5];
					g_esGeneral.g_iPlayerCount[0] = iCount;
				}
			}
		}

		if (g_esGeneral.g_iConfigExecute & MT_CONFIG_SURVIVORCOUNT)
		{
			char sCountConfig[PLATFORM_MAX_PATH];
			int iCount = iGetHumanCount();
			BuildPath(Path_SM, sCountConfig, sizeof sCountConfig, "%s%s%i.cfg", MT_CONFIG_FILEPATH, MT_CONFIG_PATH_SURVIVORCOUNT, iCount);
			if (FileExists(sCountConfig, true))
			{
				g_esGeneral.g_iFileTimeNew[6] = GetFileTime(sCountConfig, FileTime_LastChange);
				bool bTimeCheck = g_esGeneral.g_iFileTimeOld[6] != g_esGeneral.g_iFileTimeNew[6];
				if (bTimeCheck || g_esGeneral.g_iPlayerCount[1] != iCount || bManual)
				{
					if (bTimeCheck)
					{
						vLogMessage(MT_LOG_SERVER, _, "%s %T", MT_TAG, "ReloadingConfig", LANG_SERVER, sCountConfig);
					}

					vCustomConfig(sCountConfig);
					g_esGeneral.g_iFileTimeOld[6] = g_esGeneral.g_iFileTimeNew[6];
					g_esGeneral.g_iPlayerCount[1] = iCount;
				}
			}
		}

		if (g_esGeneral.g_iConfigExecute & MT_CONFIG_INFECTEDCOUNT)
		{
			char sCountConfig[PLATFORM_MAX_PATH];
			int iCount = iGetHumanCount(true);
			BuildPath(Path_SM, sCountConfig, sizeof sCountConfig, "%s%s%i.cfg", MT_CONFIG_FILEPATH, MT_CONFIG_PATH_INFECTEDCOUNT, iCount);
			if (FileExists(sCountConfig, true))
			{
				g_esGeneral.g_iFileTimeNew[7] = GetFileTime(sCountConfig, FileTime_LastChange);
				bool bTimeCheck = g_esGeneral.g_iFileTimeOld[7] != g_esGeneral.g_iFileTimeNew[7];
				if (bTimeCheck || g_esGeneral.g_iPlayerCount[2] != iCount || bManual)
				{
					if (bTimeCheck)
					{
						vLogMessage(MT_LOG_SERVER, _, "%s %T", MT_TAG, "ReloadingConfig", LANG_SERVER, sCountConfig);
					}

					vCustomConfig(sCountConfig);
					g_esGeneral.g_iFileTimeOld[7] = g_esGeneral.g_iFileTimeNew[7];
					g_esGeneral.g_iPlayerCount[2] = iCount;
				}
			}
		}
	}
}

void vCustomConfig(const char[] savepath)
{
	DataPack dpConfig;
	CreateDataTimer(1.5, tTimerExecuteCustomConfig, dpConfig, TIMER_FLAG_NO_MAPCHANGE);
	dpConfig.WriteString(savepath);
}

void vDeveloperSettings(int developer)
{
	g_esDeveloper[developer].g_bDevVisual = false;
	g_esDeveloper[developer].g_sDevFallVoiceline = "PlayerLaugh";
	g_esDeveloper[developer].g_sDevFlashlight = "rainbow";
	g_esDeveloper[developer].g_sDevGlowOutline = "rainbow";
	g_esDeveloper[developer].g_sDevLoadout = g_bSecondGame ? "shotgun_spas,machete,molotov,first_aid_kit,pain_pills" : "autoshotgun,pistol,molotov,first_aid_kit,pain_pills,pistol";
	g_esDeveloper[developer].g_sDevSkinColor = "rainbow";
	g_esDeveloper[developer].g_flDevActionDuration = 2.0;
	g_esDeveloper[developer].g_flDevAttackBoost = 1.25;
	g_esDeveloper[developer].g_flDevDamageBoost = 1.75;
	g_esDeveloper[developer].g_flDevDamageResistance = 0.5;
	g_esDeveloper[developer].g_flDevHealPercent = 100.0;
	g_esDeveloper[developer].g_flDevJumpHeight = 100.0;
	g_esDeveloper[developer].g_flDevPipeBombDuration = 10.0;
	g_esDeveloper[developer].g_flDevPunchResistance = 0.0;
	g_esDeveloper[developer].g_flDevRewardDuration = 60.0;
	g_esDeveloper[developer].g_flDevShoveDamage = 0.025;
	g_esDeveloper[developer].g_flDevShoveRate = 0.4;
	g_esDeveloper[developer].g_flDevSpeedBoost = 1.25;
	g_esDeveloper[developer].g_iDevAccess = 0;
	g_esDeveloper[developer].g_iDevAmmoRegen = 1;
	g_esDeveloper[developer].g_iDevHealthRegen = 1;
	g_esDeveloper[developer].g_iDevInfiniteAmmo = 31;
	g_esDeveloper[developer].g_iDevLifeLeech = 5;
	g_esDeveloper[developer].g_iDevMeleeRange = 150;
	g_esDeveloper[developer].g_iDevMidairDashes = 2;
	g_esDeveloper[developer].g_iDevPanelLevel = 0;
	g_esDeveloper[developer].g_iDevParticle = MT_ROCK_FIRE;
	g_esDeveloper[developer].g_iDevReviveHealth = 100;
	g_esDeveloper[developer].g_iDevRewardTypes = MT_REWARD_HEALTH|MT_REWARD_AMMO|MT_REWARD_REFILL|MT_REWARD_ATTACKBOOST|MT_REWARD_DAMAGEBOOST|MT_REWARD_SPEEDBOOST|MT_REWARD_GODMODE|MT_REWARD_ITEM|MT_REWARD_RESPAWN|MT_REWARD_INFAMMO;
	g_esDeveloper[developer].g_iDevSpecialAmmo = 0;
	g_esDeveloper[developer].g_iDevVoicePitch = 100;
	g_esDeveloper[developer].g_iDevWeaponSkin = 1;

	vDefaultCookieSettings(developer);
}

void vExecuteFinaleConfigs(const char[] filename)
{
	if ((g_esGeneral.g_iConfigExecute & MT_CONFIG_FINALE) && g_esGeneral.g_iConfigEnable == 1)
	{
		char sFinaleConfig[PLATFORM_MAX_PATH];
		if (bIsFinaleConfigFound(filename, sFinaleConfig, sizeof sFinaleConfig))
		{
			vCustomConfig(sFinaleConfig);
		}
	}
}

void vReadAdminSettings(int admin, const char[] key, const char[] value)
{
	int iIndex = g_esGeneral.g_iTypeCounter[1];
	if (1 <= iIndex <= MT_MAXTYPES)
	{
		if (StrEqual(key, "AccessFlags", false) || StrEqual(key, "Access Flags", false) || StrEqual(key, "Access_Flags", false) || StrEqual(key, "access", false))
		{
			g_esAdmin[iIndex].g_iAccessFlags[admin] = ReadFlagString(value);
		}
		else if (StrEqual(key, "ImmunityFlags", false) || StrEqual(key, "Immunity Flags", false) || StrEqual(key, "Immunity_Flags", false) || StrEqual(key, "immunity", false))
		{
			g_esAdmin[iIndex].g_iImmunityFlags[admin] = ReadFlagString(value);
		}
	}
}

void vReadTankSettings(const char[] sub, const char[] key, const char[] value)
{
	int iIndex = g_esGeneral.g_iTypeCounter[0];
	if (1 <= iIndex <= MT_MAXTYPES)
	{
		g_esTank[iIndex].g_iGameType = iGetKeyValue(sub, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, key, "GameType", "Game Type", "Game_Type", "game", g_esTank[iIndex].g_iGameType, value, 0, 2);
		g_esTank[iIndex].g_iTankEnabled = iGetKeyValue(sub, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, key, "TankEnabled", "Tank Enabled", "Tank_Enabled", "tenabled", g_esTank[iIndex].g_iTankEnabled, value, -1, 1);
		g_esTank[iIndex].g_flTankChance = flGetKeyValue(sub, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, key, "TankChance", "Tank Chance", "Tank_Chance", "chance", g_esTank[iIndex].g_flTankChance, value, 0.0, 100.0);
		g_esTank[iIndex].g_iTankModel = iGetKeyValue(sub, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, key, "TankModel", "Tank Model", "Tank_Model", "model", g_esTank[iIndex].g_iTankModel, value, 0, 7);
		g_esTank[iIndex].g_flBurnDuration = flGetKeyValue(sub, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, key, "BurnDuration", "Burn Duration", "Burn_Duration", "burndur", g_esTank[iIndex].g_flBurnDuration, value, 0.0, 99999.0);
		g_esTank[iIndex].g_flBurntSkin = flGetKeyValue(sub, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, key, "BurntSkin", "Burnt Skin", "Burnt_Skin", "burnt", g_esTank[iIndex].g_flBurntSkin, value, -1.0, 1.0);
		g_esTank[iIndex].g_iTankNote = iGetKeyValue(sub, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, key, "TankNote", "Tank Note", "Tank_Note", "note", g_esTank[iIndex].g_iTankNote, value, 0, 1);
		g_esTank[iIndex].g_iSpawnEnabled = iGetKeyValue(sub, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, key, "SpawnEnabled", "Spawn Enabled", "Spawn_Enabled", "spawn", g_esTank[iIndex].g_iSpawnEnabled, value, -1, 1);
		g_esTank[iIndex].g_iMenuEnabled = iGetKeyValue(sub, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, key, "MenuEnabled", "Menu Enabled", "Menu_Enabled", "menu", g_esTank[iIndex].g_iMenuEnabled, value, 0, 1);
		g_esTank[iIndex].g_iCheckAbilities = iGetKeyValue(sub, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, key, "CheckAbilities", "Check Abilities", "Check_Abilities", "check", g_esTank[iIndex].g_iCheckAbilities, value, 0, 1);
		g_esTank[iIndex].g_iDeathRevert = iGetKeyValue(sub, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, key, "DeathRevert", "Death Revert", "Death_Revert", "revert", g_esTank[iIndex].g_iDeathRevert, value, 0, 1);
		g_esTank[iIndex].g_iRequiresHumans = iGetKeyValue(sub, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esTank[iIndex].g_iRequiresHumans, value, 0, 32);
		g_esTank[iIndex].g_iAnnounceArrival = iGetKeyValue(sub, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE2, key, "AnnounceArrival", "Announce Arrival", "Announce_Arrival", "arrival", g_esTank[iIndex].g_iAnnounceArrival, value, 0, 31);
		g_esTank[iIndex].g_iAnnounceDeath = iGetKeyValue(sub, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE2, key, "AnnounceDeath", "Announce Death", "Announce_Death", "death", g_esTank[iIndex].g_iAnnounceDeath, value, 0, 2);
		g_esTank[iIndex].g_iAnnounceKill = iGetKeyValue(sub, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE2, key, "AnnounceKill", "Announce Kill", "Announce_Kill", "kill", g_esTank[iIndex].g_iAnnounceKill, value, 0, 1);
		g_esTank[iIndex].g_iArrivalMessage = iGetKeyValue(sub, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE2, key, "ArrivalMessage", "Arrival Message", "Arrival_Message", "arrivalmsg", g_esTank[iIndex].g_iArrivalMessage, value, 0, 1023);
		g_esTank[iIndex].g_iArrivalSound = iGetKeyValue(sub, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE2, key, "ArrivalSound", "Arrival Sound", "Arrival_Sound", "arrivalsnd", g_esTank[iIndex].g_iArrivalSound, value, 0, 1);
		g_esTank[iIndex].g_iDeathDetails = iGetKeyValue(sub, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE2, key, "DeathDetails", "Death Details", "Death_Details", "deathdets", g_esTank[iIndex].g_iDeathDetails, value, 0, 5);
		g_esTank[iIndex].g_iDeathMessage = iGetKeyValue(sub, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE2, key, "DeathMessage", "Death Message", "Death_Message", "deathmsg", g_esTank[iIndex].g_iDeathMessage, value, 0, 1023);
		g_esTank[iIndex].g_iDeathSound = iGetKeyValue(sub, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE2, key, "DeathSound", "Death Sound", "Death_Sound", "deathsnd", g_esTank[iIndex].g_iDeathSound, value, 0, 1);
		g_esTank[iIndex].g_iKillMessage = iGetKeyValue(sub, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE2, key, "KillMessage", "Kill Message", "Kill_Message", "killmsg", g_esTank[iIndex].g_iKillMessage, value, 0, 1023);
		g_esTank[iIndex].g_iVocalizeArrival = iGetKeyValue(sub, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE2, key, "VocalizeArrival", "Vocalize Arrival", "Vocalize_Arrival", "arrivalvoc", g_esTank[iIndex].g_iVocalizeArrival, value, 0, 1);
		g_esTank[iIndex].g_iVocalizeDeath = iGetKeyValue(sub, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE2, key, "VocalizeDeath", "Vocalize Death", "Vocalize_Death", "deathvoc", g_esTank[iIndex].g_iVocalizeDeath, value, 0, 1);
		g_esTank[iIndex].g_iTeammateLimit = iGetKeyValue(sub, MT_CONFIG_SECTION_REWARDS, MT_CONFIG_SECTION_REWARDS, MT_CONFIG_SECTION_REWARDS, MT_CONFIG_SECTION_REWARDS, key, "TeammateLimit", "Teammate Limit", "Teammate_Limit", "teamlimit", g_esTank[iIndex].g_iTeammateLimit, value, 0, 32);
		g_esTank[iIndex].g_iAutoAggravate = iGetKeyValue(sub, MT_CONFIG_SECTION_COMP, MT_CONFIG_SECTION_COMP, MT_CONFIG_SECTION_COMP, MT_CONFIG_SECTION_COMP2, key, "AutoAggravate", "Auto Aggravate", "Auto_Aggravate", "autoaggro", g_esTank[iIndex].g_iAutoAggravate, value, 0, 1);
		g_esTank[iIndex].g_iGlowEnabled = iGetKeyValue(sub, MT_CONFIG_SECTION_GLOW, MT_CONFIG_SECTION_GLOW, MT_CONFIG_SECTION_GLOW, MT_CONFIG_SECTION_GLOW, key, "GlowEnabled", "Glow Enabled", "Glow_Enabled", "genabled", g_esTank[iIndex].g_iGlowEnabled, value, 0, 1);
		g_esTank[iIndex].g_iGlowFlashing = iGetKeyValue(sub, MT_CONFIG_SECTION_GLOW, MT_CONFIG_SECTION_GLOW, MT_CONFIG_SECTION_GLOW, MT_CONFIG_SECTION_GLOW, key, "GlowFlashing", "Glow Flashing", "Glow_Flashing", "flashing", g_esTank[iIndex].g_iGlowFlashing, value, 0, 1);
		g_esTank[iIndex].g_iGlowType = iGetKeyValue(sub, MT_CONFIG_SECTION_GLOW, MT_CONFIG_SECTION_GLOW, MT_CONFIG_SECTION_GLOW, MT_CONFIG_SECTION_GLOW, key, "GlowType", "Glow Type", "Glow_Type", "type", g_esTank[iIndex].g_iGlowType, value, 0, 1);
		g_esTank[iIndex].g_iBaseHealth = iGetKeyValue(sub, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, key, "BaseHealth", "Base Health", "Base_Health", "basehp", g_esTank[iIndex].g_iBaseHealth, value, 0, MT_MAXHEALTH);
		g_esTank[iIndex].g_iDisplayHealth = iGetKeyValue(sub, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, key, "DisplayHealth", "Display Health", "Display_Health", "displayhp", g_esTank[iIndex].g_iDisplayHealth, value, 0, 11);
		g_esTank[iIndex].g_iDisplayHealthType = iGetKeyValue(sub, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, key, "DisplayHealthType", "Display Health Type", "Display_Health_Type", "displaytype", g_esTank[iIndex].g_iDisplayHealthType, value, 0, 2);
		g_esTank[iIndex].g_iExtraHealth = iGetKeyValue(sub, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, key, "ExtraHealth", "Extra Health", "Extra_Health", "extrahp", g_esTank[iIndex].g_iExtraHealth, value, MT_MAX_HEALTH_REDUCTION, MT_MAXHEALTH);
		g_esTank[iIndex].g_flHealPercentMultiplier = flGetKeyValue(sub, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, key, "HealthPercentageMultiplier", "Health Percentage Multiplier", "Health_Percentage_Multiplier", "hpmulti", g_esTank[iIndex].g_flHealPercentMultiplier, value, 1.0, 99999.0);
		g_esTank[iIndex].g_iHumanMultiplierMode = iGetKeyValue(sub, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, key, "HumanMultiplierMode", "Human Multiplier Mode", "Human_Multiplier_Mode", "humanmultimode", g_esTank[iIndex].g_iHumanMultiplierMode, value, 0, 1);
		g_esTank[iIndex].g_iMinimumHumans = iGetKeyValue(sub, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, key, "MinimumHumans", "Minimum Humans", "Minimum_Humans", "minhumans", g_esTank[iIndex].g_iMinimumHumans, value, 1, 32);
		g_esTank[iIndex].g_iMultiplyHealth = iGetKeyValue(sub, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, key, "MultiplyHealth", "Multiply Health", "Multiply_Health", "multihp", g_esTank[iIndex].g_iMultiplyHealth, value, 0, 3);
		g_esTank[iIndex].g_iHumanSupport = iGetKeyValue(sub, MT_CONFIG_SECTION_HUMAN, MT_CONFIG_SECTION_HUMAN2, MT_CONFIG_SECTION_HUMAN3, MT_CONFIG_SECTION_HUMAN4, key, MT_CONFIG_SECTION_HUMAN, MT_CONFIG_SECTION_HUMAN2, MT_CONFIG_SECTION_HUMAN3, MT_CONFIG_SECTION_HUMAN4, g_esTank[iIndex].g_iHumanSupport, value, 0, 2);
		g_esTank[iIndex].g_iTypeLimit = iGetKeyValue(sub, MT_CONFIG_SECTION_SPAWN, MT_CONFIG_SECTION_SPAWN, MT_CONFIG_SECTION_SPAWN, MT_CONFIG_SECTION_SPAWN, key, "TypeLimit", "Type Limit", "Type_Limit", "typelimit", g_esTank[iIndex].g_iTypeLimit, value, 0, 32);
		g_esTank[iIndex].g_iFinaleTank = iGetKeyValue(sub, MT_CONFIG_SECTION_SPAWN, MT_CONFIG_SECTION_SPAWN, MT_CONFIG_SECTION_SPAWN, MT_CONFIG_SECTION_SPAWN, key, "FinaleTank", "Finale Tank", "Finale_Tank", "finale", g_esTank[iIndex].g_iFinaleTank, value, 0, 4);
		g_esTank[iIndex].g_flCloseAreasOnly = flGetKeyValue(sub, MT_CONFIG_SECTION_SPAWN, MT_CONFIG_SECTION_SPAWN, MT_CONFIG_SECTION_SPAWN, MT_CONFIG_SECTION_SPAWN, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esTank[iIndex].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esTank[iIndex].g_flOpenAreasOnly = flGetKeyValue(sub, MT_CONFIG_SECTION_SPAWN, MT_CONFIG_SECTION_SPAWN, MT_CONFIG_SECTION_SPAWN, MT_CONFIG_SECTION_SPAWN, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esTank[iIndex].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esTank[iIndex].g_iBossBaseType = iGetKeyValue(sub, MT_CONFIG_SECTION_BOSS, MT_CONFIG_SECTION_BOSS, MT_CONFIG_SECTION_BOSS, MT_CONFIG_SECTION_BOSS, key, "BossBaseType", "Boss Base Type", "Boss_Base_Type", "bossbase", g_esTank[iIndex].g_iBossBaseType, value, 0, MT_MAXTYPES);
		g_esTank[iIndex].g_iBossLimit = iGetKeyValue(sub, MT_CONFIG_SECTION_BOSS, MT_CONFIG_SECTION_BOSS, MT_CONFIG_SECTION_BOSS, MT_CONFIG_SECTION_BOSS, key, "BossLimit", "Boss Limit", "Boss_Limit", "bosslimit", g_esTank[iIndex].g_iBossLimit, value, 0, 32);
		g_esTank[iIndex].g_iBossStages = iGetKeyValue(sub, MT_CONFIG_SECTION_BOSS, MT_CONFIG_SECTION_BOSS, MT_CONFIG_SECTION_BOSS, MT_CONFIG_SECTION_BOSS, key, "BossStages", "Boss Stages", "Boss_Stages", "bossstages", g_esTank[iIndex].g_iBossStages, value, 1, 4);
		g_esTank[iIndex].g_iRandomTank = iGetKeyValue(sub, MT_CONFIG_SECTION_RANDOM, MT_CONFIG_SECTION_RANDOM, MT_CONFIG_SECTION_RANDOM, MT_CONFIG_SECTION_RANDOM, key, "RandomTank", "Random Tank", "Random_Tank", "random", g_esTank[iIndex].g_iRandomTank, value, 0, 1);
		g_esTank[iIndex].g_flRandomDuration = flGetKeyValue(sub, MT_CONFIG_SECTION_RANDOM, MT_CONFIG_SECTION_RANDOM, MT_CONFIG_SECTION_RANDOM, MT_CONFIG_SECTION_RANDOM, key, "RandomDuration", "Random Duration", "Random_Duration", "randduration", g_esTank[iIndex].g_flRandomDuration, value, 0.1, 99999.0);
		g_esTank[iIndex].g_flRandomInterval = flGetKeyValue(sub, MT_CONFIG_SECTION_RANDOM, MT_CONFIG_SECTION_RANDOM, MT_CONFIG_SECTION_RANDOM, MT_CONFIG_SECTION_RANDOM, key, "RandomInterval", "Random Interval", "Random_Interval", "randinterval", g_esTank[iIndex].g_flRandomInterval, value, 0.1, 99999.0);
		g_esTank[iIndex].g_flTransformDelay = flGetKeyValue(sub, MT_CONFIG_SECTION_TRANSFORM, MT_CONFIG_SECTION_TRANSFORM, MT_CONFIG_SECTION_TRANSFORM, MT_CONFIG_SECTION_TRANSFORM, key, "TransformDelay", "Transform Delay", "Transform_Delay", "transdelay", g_esTank[iIndex].g_flTransformDelay, value, 0.1, 99999.0);
		g_esTank[iIndex].g_flTransformDuration = flGetKeyValue(sub, MT_CONFIG_SECTION_TRANSFORM, MT_CONFIG_SECTION_TRANSFORM, MT_CONFIG_SECTION_TRANSFORM, MT_CONFIG_SECTION_TRANSFORM, key, "TransformDuration", "Transform Duration", "Transform_Duration", "transduration", g_esTank[iIndex].g_flTransformDuration, value, 0.1, 99999.0);
		g_esTank[iIndex].g_iSpawnType = iGetKeyValue(sub, MT_CONFIG_SECTION_SPAWN, MT_CONFIG_SECTION_SPAWN, MT_CONFIG_SECTION_SPAWN, MT_CONFIG_SECTION_SPAWN, key, "SpawnType", "Spawn Type", "Spawn_Type", "spawntype", g_esTank[iIndex].g_iSpawnType, value, 0, 4);
		g_esTank[iIndex].g_iRockModel = iGetKeyValue(sub, MT_CONFIG_SECTION_PROPS, MT_CONFIG_SECTION_PROPS, MT_CONFIG_SECTION_PROPS, MT_CONFIG_SECTION_PROPS, key, "RockModel", "Rock Model", "Rock_Model", "rockmodel", g_esTank[iIndex].g_iRockModel, value, 0, 2);
		g_esTank[iIndex].g_iPropsAttached = iGetKeyValue(sub, MT_CONFIG_SECTION_PROPS, MT_CONFIG_SECTION_PROPS, MT_CONFIG_SECTION_PROPS, MT_CONFIG_SECTION_PROPS, key, "PropsAttached", "Props Attached", "Props_Attached", "attached", g_esTank[iIndex].g_iPropsAttached, value, 0, 511);
		g_esTank[iIndex].g_iBodyEffects = iGetKeyValue(sub, MT_CONFIG_SECTION_PARTICLES, MT_CONFIG_SECTION_PARTICLES, MT_CONFIG_SECTION_PARTICLES, MT_CONFIG_SECTION_PARTICLES, key, "BodyEffects", "Body Effects", "Body_Effects", "body", g_esTank[iIndex].g_iBodyEffects, value, 0, 127);
		g_esTank[iIndex].g_iRockEffects = iGetKeyValue(sub, MT_CONFIG_SECTION_PARTICLES, MT_CONFIG_SECTION_PARTICLES, MT_CONFIG_SECTION_PARTICLES, MT_CONFIG_SECTION_PARTICLES, key, "RockEffects", "Rock Effects", "Rock_Effects", "rock", g_esTank[iIndex].g_iRockEffects, value, 0, 15);
		g_esTank[iIndex].g_flAttackInterval = flGetKeyValue(sub, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE2, key, "AttackInterval", "Attack Interval", "Attack_Interval", "attack", g_esTank[iIndex].g_flAttackInterval, value, 0.0, 99999.0);
		g_esTank[iIndex].g_flClawDamage = flGetKeyValue(sub, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE2, key, "ClawDamage", "Claw Damage", "Claw_Damage", "claw", g_esTank[iIndex].g_flClawDamage, value, -1.0, 99999.0);
		g_esTank[iIndex].g_iGroundPound = iGetKeyValue(sub, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE2, key, "GroundPound", "Ground Pound", "Ground_Pound", "pound", g_esTank[iIndex].g_iGroundPound, value, 0, 1);
		g_esTank[iIndex].g_flHittableDamage = flGetKeyValue(sub, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE2, key, "HittableDamage", "Hittable Damage", "Hittable_Damage", "hittable", g_esTank[iIndex].g_flHittableDamage, value, -1.0, 99999.0);
		g_esTank[iIndex].g_flIncapDamageMultiplier = flGetKeyValue(sub, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE2, key, "IncapDamageMultiplier", "Incap Damage Multiplier", "Incap_Damage_Multiplier", "incapdmgmulti", g_esTank[iIndex].g_flIncapDamageMultiplier, value, 1.0, 99999.0);
		g_esTank[iIndex].g_flPunchForce = flGetKeyValue(sub, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE2, key, "PunchForce", "Punch Force", "Punch_Force", "punchf", g_esTank[iIndex].g_flPunchForce, value, -1.0, 99999.0);
		g_esTank[iIndex].g_flPunchThrow = flGetKeyValue(sub, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE2, key, "PunchThrow", "Punch Throw", "Punch_Throw", "puncht", g_esTank[iIndex].g_flPunchThrow, value, 0.0, 100.0);
		g_esTank[iIndex].g_flRockDamage = flGetKeyValue(sub, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE2, key, "RockDamage", "Rock Damage", "Rock_Damage", "rockdmg", g_esTank[iIndex].g_flRockDamage, value, -1.0, 99999.0);
		g_esTank[iIndex].g_iRockSound = iGetKeyValue(sub, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE2, key, "RockSound", "Rock Sound", "Rock_Sound", "rocksnd", g_esTank[iIndex].g_iRockSound, value, 0, 1);
		g_esTank[iIndex].g_flRunSpeed = flGetKeyValue(sub, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE2, key, "RunSpeed", "Run Speed", "Run_Speed", "speed", g_esTank[iIndex].g_flRunSpeed, value, 0.0, 3.0);
		g_esTank[iIndex].g_iSkipIncap = iGetKeyValue(sub, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE2, key, "SkipIncap", "Skip Incap", "Skip_Incap", "incap", g_esTank[iIndex].g_iSkipIncap, value, 0, 1);
		g_esTank[iIndex].g_iSkipTaunt = iGetKeyValue(sub, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE2, key, "SkipTaunt", "Skip Taunt", "Skip_Taunt", "taunt", g_esTank[iIndex].g_iSkipTaunt, value, 0, 1);
		g_esTank[iIndex].g_iSweepFist = iGetKeyValue(sub, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE2, key, "SweepFist", "Sweep Fist", "Sweep_Fist", "sweep", g_esTank[iIndex].g_iSweepFist, value, 0, 1);
		g_esTank[iIndex].g_flThrowInterval = flGetKeyValue(sub, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE2, key, "ThrowInterval", "Throw Interval", "Throw_Interval", "throw", g_esTank[iIndex].g_flThrowInterval, value, 0.0, 99999.0);
		g_esTank[iIndex].g_iBulletImmunity = iGetKeyValue(sub, MT_CONFIG_SECTION_IMMUNE, MT_CONFIG_SECTION_IMMUNE, MT_CONFIG_SECTION_IMMUNE, MT_CONFIG_SECTION_IMMUNE2, key, "BulletImmunity", "Bullet Immunity", "Bullet_Immunity", "bullet", g_esTank[iIndex].g_iBulletImmunity, value, 0, 1);
		g_esTank[iIndex].g_iExplosiveImmunity = iGetKeyValue(sub, MT_CONFIG_SECTION_IMMUNE, MT_CONFIG_SECTION_IMMUNE, MT_CONFIG_SECTION_IMMUNE, MT_CONFIG_SECTION_IMMUNE2, key, "ExplosiveImmunity", "Explosive Immunity", "Explosive_Immunity", "explosive", g_esTank[iIndex].g_iExplosiveImmunity, value, 0, 1);
		g_esTank[iIndex].g_iFireImmunity = iGetKeyValue(sub, MT_CONFIG_SECTION_IMMUNE, MT_CONFIG_SECTION_IMMUNE, MT_CONFIG_SECTION_IMMUNE, MT_CONFIG_SECTION_IMMUNE2, key, "FireImmunity", "Fire Immunity", "Fire_Immunity", "fire", g_esTank[iIndex].g_iFireImmunity, value, 0, 1);
		g_esTank[iIndex].g_iHittableImmunity = iGetKeyValue(sub, MT_CONFIG_SECTION_IMMUNE, MT_CONFIG_SECTION_IMMUNE, MT_CONFIG_SECTION_IMMUNE, MT_CONFIG_SECTION_IMMUNE2, key, "HittableImmunity", "Hittable Immunity", "Hittable_Immunity", "hittable", g_esTank[iIndex].g_iHittableImmunity, value, 0, 1);
		g_esTank[iIndex].g_iMeleeImmunity = iGetKeyValue(sub, MT_CONFIG_SECTION_IMMUNE, MT_CONFIG_SECTION_IMMUNE, MT_CONFIG_SECTION_IMMUNE, MT_CONFIG_SECTION_IMMUNE2, key, "MeleeImmunity", "Melee Immunity", "Melee_Immunity", "melee", g_esTank[iIndex].g_iMeleeImmunity, value, 0, 1);
		g_esTank[iIndex].g_iVomitImmunity = iGetKeyValue(sub, MT_CONFIG_SECTION_IMMUNE, MT_CONFIG_SECTION_IMMUNE, MT_CONFIG_SECTION_IMMUNE, MT_CONFIG_SECTION_IMMUNE2, key, "VomitImmunity", "Vomit Immunity", "Vomit_Immunity", "vomit", g_esTank[iIndex].g_iVomitImmunity, value, 0, 1);
		g_esTank[iIndex].g_iAccessFlags = iGetAdminFlagsValue(sub, MT_CONFIG_SECTION_ADMIN, MT_CONFIG_SECTION_ADMIN, MT_CONFIG_SECTION_ADMIN, MT_CONFIG_SECTION_ADMIN2, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esTank[iIndex].g_iImmunityFlags = iGetAdminFlagsValue(sub, MT_CONFIG_SECTION_ADMIN, MT_CONFIG_SECTION_ADMIN, MT_CONFIG_SECTION_ADMIN, MT_CONFIG_SECTION_ADMIN2, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);

		vGetKeyValue(sub, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, key, "HealthCharacters", "Health Characters", "Health_Characters", "hpchars", g_esTank[iIndex].g_sHealthCharacters, sizeof esTank::g_sHealthCharacters, value);
		vGetKeyValue(sub, MT_CONFIG_SECTION_COMBO, MT_CONFIG_SECTION_COMBO, MT_CONFIG_SECTION_COMBO, MT_CONFIG_SECTION_COMBO, key, "ComboSet", "Combo Set", "Combo_Set", "set", g_esTank[iIndex].g_sComboSet, sizeof esTank::g_sComboSet, value);

		if (StrEqual(sub, MT_CONFIG_SECTION_GENERAL, false))
		{
			if (StrEqual(key, "SkinColor", false) || StrEqual(key, "Skin Color", false) || StrEqual(key, "Skin_Color", false) || StrEqual(key, "skin", false))
			{
				char sValue[64], sSet[4][4];
				vGetConfigColors(sValue, sizeof sValue, value);
				strcopy(g_esTank[iIndex].g_sSkinColor, sizeof esTank::g_sSkinColor, value);
				ReplaceString(sValue, sizeof sValue, " ", "");
				ExplodeString(sValue, ",", sSet, sizeof sSet, sizeof sSet[]);
				for (int iPos = 0; iPos < (sizeof esTank::g_iSkinColor); iPos++)
				{
					g_esTank[iIndex].g_iSkinColor[iPos] = (sSet[iPos][0] != '\0' && StringToInt(sSet[iPos]) >= 0) ? iClamp(StringToInt(sSet[iPos]), 0, 255) : -1;
				}
			}
			else
			{
				vGetKeyValue(sub, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, key, "TankName", "Tank Name", "Tank_Name", "name", g_esTank[iIndex].g_sTankName, sizeof esTank::g_sTankName, value);
			}
		}
		else if (StrEqual(sub, MT_CONFIG_SECTION_REWARDS, false))
		{
			char sValue[1280], sSet[7][320];
			strcopy(sValue, sizeof sValue, value);
			ReplaceString(sValue, sizeof sValue, " ", "");
			ExplodeString(sValue, ",", sSet, sizeof sSet, sizeof sSet[]);
			for (int iPos = 0; iPos < (sizeof esTank::g_iStackLimits); iPos++)
			{
				if (iPos < (sizeof esTank::g_iRewardEnabled))
				{
					g_esTank[iIndex].g_flRewardChance[iPos] = flGetClampedValue(key, "RewardChance", "Reward Chance", "Reward_Chance", "chance", g_esTank[iIndex].g_flRewardChance[iPos], sSet[iPos], 0.1, 100.0);
					g_esTank[iIndex].g_flRewardDuration[iPos] = flGetClampedValue(key, "RewardDuration", "Reward Duration", "Reward_Duration", "duration", g_esTank[iIndex].g_flRewardDuration[iPos], sSet[iPos], 0.1, 99999.0);
					g_esTank[iIndex].g_flRewardPercentage[iPos] = flGetClampedValue(key, "RewardPercentage", "Reward Percentage", "Reward_Percentage", "percent", g_esTank[iIndex].g_flRewardPercentage[iPos], sSet[iPos], 0.1, 100.0);
					g_esTank[iIndex].g_flActionDurationReward[iPos] = flGetClampedValue(key, "ActionDurationReward", "Action Duration Reward", "Action_Duration_Reward", "actionduration", g_esTank[iIndex].g_flActionDurationReward[iPos], sSet[iPos], 0.0, 99999.0);
					g_esTank[iIndex].g_flAttackBoostReward[iPos] = flGetClampedValue(key, "AttackBoostReward", "Attack Boost Reward", "Attack_Boost_Reward", "attackboost", g_esTank[iIndex].g_flAttackBoostReward[iPos], sSet[iPos], 0.0, 99999.0);
					g_esTank[iIndex].g_flDamageBoostReward[iPos] = flGetClampedValue(key, "DamageBoostReward", "Damage Boost Reward", "Damage_Boost_Reward", "dmgboost", g_esTank[iIndex].g_flDamageBoostReward[iPos], sSet[iPos], 0.0, 99999.0);
					g_esTank[iIndex].g_flDamageResistanceReward[iPos] = flGetClampedValue(key, "DamageResistanceReward", "Damage Resistance Reward", "Damage_Resistance_Reward", "dmgres", g_esTank[iIndex].g_flDamageResistanceReward[iPos], sSet[iPos], 0.0, 1.0);
					g_esTank[iIndex].g_flHealPercentReward[iPos] = flGetClampedValue(key, "HealPercentReward", "Heal Percent Reward", "Heal_Percent_Reward", "healpercent", g_esTank[iIndex].g_flHealPercentReward[iPos], sSet[iPos], 0.0, 100.0);
					g_esTank[iIndex].g_flJumpHeightReward[iPos] = flGetClampedValue(key, "JumpHeightReward", "Jump Height Reward", "Jump_Height_Reward", "jumpheight", g_esTank[iIndex].g_flJumpHeightReward[iPos], sSet[iPos], 0.0, 99999.0);
					g_esTank[iIndex].g_flLoopingVoicelineInterval[iPos] = flGetClampedValue(key, "LoopingVoicelineInterval", "Looping Voiceline Interval", "Looping_Voiceline_Interval", "loopinterval", g_esTank[iIndex].g_flLoopingVoicelineInterval[iPos], sSet[iPos], 0.1, 99999.0);
					g_esTank[iIndex].g_flPipeBombDurationReward[iPos] = flGetClampedValue(key, "PipebombDurationReward", "Pipebomb Duration Reward", "Pipebomb_Duration_Reward", "pipeduration", g_esTank[iIndex].g_flPipeBombDurationReward[iPos], sSet[iPos], 0.0, 99999.0);
					g_esTank[iIndex].g_flPunchResistanceReward[iPos] = flGetClampedValue(key, "PunchResistanceReward", "Punch Resistance Reward", "Punch_Resistance_Reward", "punchres", g_esTank[iIndex].g_flPunchResistanceReward[iPos], sSet[iPos], 0.0, 1.0);
					g_esTank[iIndex].g_flShoveDamageReward[iPos] = flGetClampedValue(key, "ShoveDamageReward", "Shove Damage Reward", "Shove_Damage_Reward", "shovedmg", g_esTank[iIndex].g_flShoveDamageReward[iPos], sSet[iPos], 0.0, 99999.0);
					g_esTank[iIndex].g_flShoveRateReward[iPos] = flGetClampedValue(key, "ShoveRateReward", "Shove Rate Reward", "Shove_Rate_Reward", "shoverate", g_esTank[iIndex].g_flShoveRateReward[iPos], sSet[iPos], 0.0, 99999.0);
					g_esTank[iIndex].g_flSpeedBoostReward[iPos] = flGetClampedValue(key, "SpeedBoostReward", "Speed Boost Reward", "Speed_Boost_Reward", "speedboost", g_esTank[iIndex].g_flSpeedBoostReward[iPos], sSet[iPos], 0.0, 99999.0);
					g_esTank[iIndex].g_iRewardEnabled[iPos] = iGetClampedValue(key, "RewardEnabled", "Reward Enabled", "Reward_Enabled", "renabled", g_esTank[iIndex].g_iRewardEnabled[iPos], sSet[iPos], -1, 2147483647);
					g_esTank[iIndex].g_iRewardBots[iPos] = iGetClampedValue(key, "RewardBots", "Reward Bots", "Reward_Bots", "bots", g_esTank[iIndex].g_iRewardBots[iPos], sSet[iPos], -1, 2147483647);
					g_esTank[iIndex].g_iRewardEffect[iPos] = iGetClampedValue(key, "RewardEffect", "Reward Effect", "Reward_Effect", "effect", g_esTank[iIndex].g_iRewardEffect[iPos], sSet[iPos], 0, 15);
					g_esTank[iIndex].g_iRewardNotify[iPos] = iGetClampedValue(key, "RewardNotify", "Reward Notify", "Reward_Notify", "rnotify", g_esTank[iIndex].g_iRewardNotify[iPos], sSet[iPos], 0, 3);
					g_esTank[iIndex].g_iRewardVisual[iPos] = iGetClampedValue(key, "RewardVisual", "Reward Visual", "Reward_Visual", "visual", g_esTank[iIndex].g_iRewardVisual[iPos], sSet[iPos], 0, 63);
					g_esTank[iIndex].g_iAmmoBoostReward[iPos] = iGetClampedValue(key, "AmmoBoostReward", "Ammo Boost Reward", "Ammo_Boost_Reward", "ammoboost", g_esTank[iIndex].g_iAmmoBoostReward[iPos], sSet[iPos], 0, 1);
					g_esTank[iIndex].g_iAmmoRegenReward[iPos] = iGetClampedValue(key, "AmmoRegenReward", "Ammo Regen Reward", "Ammo_Regen_Reward", "ammoregen", g_esTank[iIndex].g_iAmmoRegenReward[iPos], sSet[iPos], 0, 99999);
					g_esTank[iIndex].g_iBunnyHopReward[iPos] = iGetClampedValue(key, "BunnyHopReward", "Bunny Hop Reward", "Bunny_Hop_Reward", "bhop", g_esTank[iIndex].g_iBunnyHopReward[iPos], sSet[iPos], 0, 1);
					g_esTank[iIndex].g_iBurstDoorsReward[iPos] = iGetClampedValue(key, "BurstDoorsReward", "Burst Doors Reward", "Burst_Doors_Reward", "burstdoors", g_esTank[iIndex].g_iBurstDoorsReward[iPos], sSet[iPos], 0, 1);
					g_esTank[iIndex].g_iCleanKillsReward[iPos] = iGetClampedValue(key, "CleanKillsReward", "Clean Kills Reward", "Clean_Kills_Reward", "cleankills", g_esTank[iIndex].g_iCleanKillsReward[iPos], sSet[iPos], 0, 1);
					g_esTank[iIndex].g_iFriendlyFireReward[iPos] = iGetClampedValue(key, "FriendlyFireReward", "Friendly Fire Reward", "Friendly_Fire_Reward", "friendlyfire", g_esTank[iIndex].g_iFriendlyFireReward[iPos], sSet[iPos], 0, 1);
					g_esTank[iIndex].g_iHealthRegenReward[iPos] = iGetClampedValue(key, "HealthRegenReward", "Health Regen Reward", "Health_Regen_Reward", "hpregen", g_esTank[iIndex].g_iHealthRegenReward[iPos], sSet[iPos], 0, MT_MAXHEALTH);
					g_esTank[iIndex].g_iHollowpointAmmoReward[iPos] = iGetClampedValue(key, "HollowpointAmmoReward", "Hollowpoint Ammo Reward", "Hollowpoint_Ammo_Reward", "hollowpoint", g_esTank[iIndex].g_iHollowpointAmmoReward[iPos], sSet[iPos], 0, 1);
					g_esTank[iIndex].g_iInextinguishableFireReward[iPos] = iGetClampedValue(key, "InextinguishableFireReward", "Inextinguishable Fire Reward", "Inextinguishable_Fire_Reward", "inexfire", g_esTank[iIndex].g_iInextinguishableFireReward[iPos], sSet[iPos], 0, 1);
					g_esTank[iIndex].g_iInfiniteAmmoReward[iPos] = iGetClampedValue(key, "InfiniteAmmoReward", "Infinite Ammo Reward", "Infinite_Ammo_Reward", "infammo", g_esTank[iIndex].g_iInfiniteAmmoReward[iPos], sSet[iPos], 0, 31);
					g_esTank[iIndex].g_iLadderActionsReward[iPos] = iGetClampedValue(key, "LadderActionsReward", "Ladder Actions Reward", "Ladder_Action_Reward", "ladderactions", g_esTank[iIndex].g_iLadderActionsReward[iPos], sSet[iPos], 0, 1);
					g_esTank[iIndex].g_iLadyKillerReward[iPos] = iGetClampedValue(key, "LadyKillerReward", "Lady Killer Reward", "Lady_Killer_Reward", "ladykiller", g_esTank[iIndex].g_iLadyKillerReward[iPos], sSet[iPos], 0, 99999);
					g_esTank[iIndex].g_iLifeLeechReward[iPos] = iGetClampedValue(key, "LifeLeechReward", "Life Leech Reward", "Life_Leech_Reward", "lifeleech", g_esTank[iIndex].g_iLifeLeechReward[iPos], sSet[iPos], 0, MT_MAXHEALTH);
					g_esTank[iIndex].g_iMeleeRangeReward[iPos] = iGetClampedValue(key, "MeleeRangeReward", "Melee Range Reward", "Melee_Range_Reward", "meleerange", g_esTank[iIndex].g_iMeleeRangeReward[iPos], sSet[iPos], 0, 99999);
					g_esTank[iIndex].g_iMidairDashesReward[iPos] = iGetClampedValue(key, "MidairDashesReward", "Midair Dashes Reward", "Midair_Dashes_Reward", "midairdashes", g_esTank[iIndex].g_iMidairDashesReward[iPos], sSet[iPos], 0, 99999);
					g_esTank[iIndex].g_iParticleEffectVisual[iPos] = iGetClampedValue(key, "ParticleEffectVisual", "Particle Effect Visual", "Particle_Effect_Visual", "particle", g_esTank[iIndex].g_iParticleEffectVisual[iPos], sSet[iPos], 0, 15);
					g_esTank[iIndex].g_iPrefsNotify[iPos] = iGetClampedValue(key, "PrefsNotify", "Prefs Notify", "Prefs_Notify", "pnotify", g_esTank[iIndex].g_iPrefsNotify[iPos], sSet[iPos], 0, 1);
					g_esTank[iIndex].g_iRecoilDampenerReward[iPos] = iGetClampedValue(key, "RecoilDampenerReward", "Recoil Dampener Reward", "Recoil_Dampener_Reward", "recoil", g_esTank[iIndex].g_iRecoilDampenerReward[iPos], sSet[iPos], 0, 1);
					g_esTank[iIndex].g_iRespawnLoadoutReward[iPos] = iGetClampedValue(key, "RespawnLoadoutReward", "Respawn Loadout Reward", "Respawn_Loadout_Reward", "resloadout", g_esTank[iIndex].g_iRespawnLoadoutReward[iPos], sSet[iPos], 0, 1);
					g_esTank[iIndex].g_iReviveHealthReward[iPos] = iGetClampedValue(key, "ReviveHealthReward", "Revive Health Reward", "Revive_Health_Reward", "revivehp", g_esTank[iIndex].g_iReviveHealthReward[iPos], sSet[iPos], 0, MT_MAXHEALTH);
					g_esTank[iIndex].g_iShareRewards[iPos] = iGetClampedValue(key, "ShareRewards", "Share Rewards", "Share_Rewards", "share", g_esTank[iIndex].g_iShareRewards[iPos], sSet[iPos], 0, 3);
					g_esTank[iIndex].g_iShovePenaltyReward[iPos] = iGetClampedValue(key, "ShovePenaltyReward", "Shove Penalty Reward", "Shove_Penalty_Reward", "shovepenalty", g_esTank[iIndex].g_iShovePenaltyReward[iPos], sSet[iPos], 0, 1);
					g_esTank[iIndex].g_iSledgehammerRoundsReward[iPos] = iGetClampedValue(key, "SledgehammerRoundsReward", "Sledgehammer Rounds Reward", "Sledgehammer_Rounds_Reward", "sledgehammer", g_esTank[iIndex].g_iSledgehammerRoundsReward[iPos], sSet[iPos], 0, 1);
					g_esTank[iIndex].g_iSpecialAmmoReward[iPos] = iGetClampedValue(key, "SpecialAmmoReward", "Special Ammo Reward", "Special_Ammo_Reward", "specialammo", g_esTank[iIndex].g_iSpecialAmmoReward[iPos], sSet[iPos], 0, 3);
					g_esTank[iIndex].g_iStackRewards[iPos] = iGetClampedValue(key, "StackRewards", "Stack Rewards", "Stack_Rewards", "stack", g_esTank[iIndex].g_iStackRewards[iPos], sSet[iPos], 0, 2147483647);
					g_esTank[iIndex].g_iThornsReward[iPos] = iGetClampedValue(key, "ThornsReward", "Thorns Reward", "Thorns_Reward", "thorns", g_esTank[iIndex].g_iThornsReward[iPos], sSet[iPos], 0, 1);
					g_esTank[iIndex].g_iUsefulRewards[iPos] = iGetClampedValue(key, "UsefulRewards", "Useful Rewards", "Useful_Rewards", "useful", g_esTank[iIndex].g_iUsefulRewards[iPos], sSet[iPos], 0, 15);
					g_esTank[iIndex].g_iVoicePitchVisual[iPos] = iGetClampedValue(key, "VoicePitchVisual", "Voice Pitch Visual", "Voice_Pitch_Visual", "voicepitch", g_esTank[iIndex].g_iVoicePitchVisual[iPos], sSet[iPos], 0, 255);

					vGetConfigColors(sValue, sizeof sValue, sSet[iPos], ';');
					vGetStringValue(key, "BodyColorVisual", "Body Color Visual", "Body_Color_Visual", "bodycolor", iPos, g_esTank[iIndex].g_sBodyColorVisual, sizeof esTank::g_sBodyColorVisual, g_esTank[iIndex].g_sBodyColorVisual2, sizeof esTank::g_sBodyColorVisual2, g_esTank[iIndex].g_sBodyColorVisual3, sizeof esTank::g_sBodyColorVisual3, g_esTank[iIndex].g_sBodyColorVisual4, sizeof esTank::g_sBodyColorVisual4, sValue);
					vGetStringValue(key, "FallVoicelineReward", "Fall Voiceline Reward", "Fall_Voiceline_Reward", "fallvoice", iPos, g_esTank[iIndex].g_sFallVoicelineReward, sizeof esTank::g_sFallVoicelineReward, g_esTank[iIndex].g_sFallVoicelineReward2, sizeof esTank::g_sFallVoicelineReward2, g_esTank[iIndex].g_sFallVoicelineReward3, sizeof esTank::g_sFallVoicelineReward3, g_esTank[iIndex].g_sFallVoicelineReward4, sizeof esTank::g_sFallVoicelineReward4, sSet[iPos]);
					vGetStringValue(key, "GlowColorVisual", "Glow Color Visual", "Glow_Color_Visual", "glowcolor", iPos, g_esTank[iIndex].g_sOutlineColorVisual, sizeof esTank::g_sOutlineColorVisual, g_esTank[iIndex].g_sOutlineColorVisual2, sizeof esTank::g_sOutlineColorVisual2, g_esTank[iIndex].g_sOutlineColorVisual3, sizeof esTank::g_sOutlineColorVisual3, g_esTank[iIndex].g_sOutlineColorVisual4, sizeof esTank::g_sOutlineColorVisual4, sValue);
					vGetStringValue(key, "ItemReward", "Item Reward", "Item_Reward", "item", iPos, g_esTank[iIndex].g_sItemReward, sizeof esTank::g_sItemReward, g_esTank[iIndex].g_sItemReward2, sizeof esTank::g_sItemReward2, g_esTank[iIndex].g_sItemReward3, sizeof esTank::g_sItemReward3, g_esTank[iIndex].g_sItemReward4, sizeof esTank::g_sItemReward4, sValue);
					vGetStringValue(key, "LightColorVisual", "Light Color Visual", "Light_Color_Visual", "lightcolor", iPos, g_esTank[iIndex].g_sLightColorVisual, sizeof esTank::g_sLightColorVisual, g_esTank[iIndex].g_sLightColorVisual2, sizeof esTank::g_sLightColorVisual2, g_esTank[iIndex].g_sLightColorVisual3, sizeof esTank::g_sLightColorVisual3, g_esTank[iIndex].g_sLightColorVisual4, sizeof esTank::g_sLightColorVisual4, sValue);
					vGetStringValue(key, "LoopingVoicelineVisual", "Looping Voiceline Visual", "Looping_Voiceline_Visual", "loopvoice", iPos, g_esTank[iIndex].g_sLoopingVoicelineVisual, sizeof esTank::g_sLoopingVoicelineVisual, g_esTank[iIndex].g_sLoopingVoicelineVisual2, sizeof esTank::g_sLoopingVoicelineVisual2, g_esTank[iIndex].g_sLoopingVoicelineVisual3, sizeof esTank::g_sLoopingVoicelineVisual3, g_esTank[iIndex].g_sLoopingVoicelineVisual4, sizeof esTank::g_sLoopingVoicelineVisual4, sSet[iPos]);
					vGetStringValue(key, "ScreenColorVisual", "Screen Color Visual", "Screen_Color_Visual", "screencolor", iPos, g_esTank[iIndex].g_sScreenColorVisual, sizeof esTank::g_sScreenColorVisual, g_esTank[iIndex].g_sScreenColorVisual2, sizeof esTank::g_sScreenColorVisual2, g_esTank[iIndex].g_sScreenColorVisual3, sizeof esTank::g_sScreenColorVisual3, g_esTank[iIndex].g_sScreenColorVisual4, sizeof esTank::g_sScreenColorVisual4, sValue);
				}

				g_esTank[iIndex].g_iStackLimits[iPos] = iGetClampedValue(key, "StackLimits", "Stack Limits", "Stack_Limits", "limits", g_esTank[iIndex].g_iStackLimits[iPos], sSet[iPos], 0, 99999);
			}
		}
		else if (StrEqual(sub, MT_CONFIG_SECTION_GLOW, false))
		{
			if (StrEqual(key, "GlowColor", false) || StrEqual(key, "Glow Color", false) || StrEqual(key, "Glow_Color", false))
			{
				char sValue[64], sSet[3][4];
				vGetConfigColors(sValue, sizeof sValue, value);
				strcopy(g_esTank[iIndex].g_sGlowColor, sizeof esTank::g_sGlowColor, value);
				ReplaceString(sValue, sizeof sValue, " ", "");
				ExplodeString(sValue, ",", sSet, sizeof sSet, sizeof sSet[]);
				for (int iPos = 0; iPos < (sizeof esTank::g_iGlowColor); iPos++)
				{
					g_esTank[iIndex].g_iGlowColor[iPos] = (sSet[iPos][0] != '\0' && StringToInt(sSet[iPos]) >= 0) ? iClamp(StringToInt(sSet[iPos]), 0, 255) : -1;
				}
			}
			else if (StrEqual(key, "GlowRange", false) || StrEqual(key, "Glow Range", false) || StrEqual(key, "Glow_Range", false))
			{
				char sValue[50], sRange[2][7];
				strcopy(sValue, sizeof sValue, value);
				ReplaceString(sValue, sizeof sValue, " ", "");
				ExplodeString(sValue, "-", sRange, sizeof sRange, sizeof sRange[]);

				g_esTank[iIndex].g_iGlowMinRange = (sRange[0][0] != '\0') ? iClamp(StringToInt(sRange[0]), 0, 99999) : g_esTank[iIndex].g_iGlowMinRange;
				g_esTank[iIndex].g_iGlowMaxRange = (sRange[1][0] != '\0') ? iClamp(StringToInt(sRange[1]), 0, 99999) : g_esTank[iIndex].g_iGlowMaxRange;
			}
		}
		else if (StrEqual(sub, MT_CONFIG_SECTION_BOSS, false))
		{
			char sValue[44], sSet[4][11];
			strcopy(sValue, sizeof sValue, value);
			ReplaceString(sValue, sizeof sValue, " ", "");
			ExplodeString(sValue, ",", sSet, sizeof sSet, sizeof sSet[]);
			for (int iPos = 0; iPos < (sizeof esTank::g_iBossHealth); iPos++)
			{
				g_esTank[iIndex].g_iBossHealth[iPos] = iGetClampedValue(key, "BossHealthStages", "Boss Health Stages", "Boss_Health_Stages", "bosshpstages", g_esTank[iIndex].g_iBossHealth[iPos], sSet[iPos], 1, MT_MAXHEALTH);
				g_esTank[iIndex].g_iBossType[iPos] = iGetClampedValue(key, "BossTypes", "Boss Types", "Boss_Types", "bosstypes", g_esTank[iIndex].g_iBossType[iPos], sSet[iPos], 1, MT_MAXTYPES);
			}
		}
		else if (StrEqual(sub, MT_CONFIG_SECTION_COMBO, false))
		{
			if (StrEqual(key, "ComboTypeChance", false) || StrEqual(key, "Combo Type Chance", false) || StrEqual(key, "Combo_Type_Chance", false) || StrEqual(key, "typechance", false))
			{
				char sValue[42], sSet[7][6];
				strcopy(sValue, sizeof sValue, value);
				ReplaceString(sValue, sizeof sValue, " ", "");
				ExplodeString(sValue, ",", sSet, sizeof sSet, sizeof sSet[]);
				for (int iPos = 0; iPos < (sizeof esTank::g_flComboTypeChance); iPos++)
				{
					g_esTank[iIndex].g_flComboTypeChance[iPos] = (sSet[iPos][0] != '\0') ? flClamp(StringToFloat(sSet[iPos]), 0.0, 100.0) : g_esTank[iIndex].g_flComboTypeChance[iPos];
				}
			}
			else
			{
				char sValue[140], sSet[10][14];
				strcopy(sValue, sizeof sValue, value);
				ReplaceString(sValue, sizeof sValue, " ", "");
				ExplodeString(sValue, ",", sSet, sizeof sSet, sizeof sSet[]);
				for (int iPos = 0; iPos < (sizeof esTank::g_flComboChance); iPos++)
				{
					if (StrEqual(key, "ComboRadius", false) || StrEqual(key, "Combo Radius", false) || StrEqual(key, "Combo_Radius", false) || StrEqual(key, "radius", false))
					{
						char sRange[2][7], sSubset[14];
						strcopy(sSubset, sizeof sSubset, sSet[iPos]);
						ReplaceString(sSubset, sizeof sSubset, " ", "");
						ExplodeString(sSubset, ";", sRange, sizeof sRange, sizeof sRange[]);

						g_esTank[iIndex].g_flComboMinRadius[iPos] = (sRange[0][0] != '\0') ? flClamp(StringToFloat(sRange[0]), -200.0, 0.0) : g_esTank[iIndex].g_flComboMinRadius[iPos];
						g_esTank[iIndex].g_flComboMaxRadius[iPos] = (sRange[1][0] != '\0') ? flClamp(StringToFloat(sRange[1]), 0.0, 200.0) : g_esTank[iIndex].g_flComboMaxRadius[iPos];
					}
					else
					{
						g_esTank[iIndex].g_flComboChance[iPos] = flGetClampedValue(key, "ComboChance", "Combo Chance", "Combo_Chance", "chance", g_esTank[iIndex].g_flComboChance[iPos], sSet[iPos], 0.0, 100.0);
						g_esTank[iIndex].g_iComboCooldown[iPos] = iGetClampedValue(key, "ComboCooldown", "Combo Cooldown", "Combo_Cooldown", "cooldown", g_esTank[iIndex].g_iComboCooldown[iPos], sSet[iPos], 0, 99999);
						g_esTank[iIndex].g_flComboDamage[iPos] = flGetClampedValue(key, "ComboDamage", "Combo Damage", "Combo_Damage", "damage", g_esTank[iIndex].g_flComboDamage[iPos], sSet[iPos], 0.0, 99999.0);
						g_esTank[iIndex].g_flComboDeathChance[iPos] = flGetClampedValue(key, "ComboDeathChance", "Combo Death Chance", "Combo_Death_Chance", "deathchance", g_esTank[iIndex].g_flComboDeathChance[iPos], sSet[iPos], 0.0, 100.0);
						g_esTank[iIndex].g_flComboDeathRange[iPos] = flGetClampedValue(key, "ComboDeathRange", "Combo Death Range", "Combo_Death_Range", "deathrange", g_esTank[iIndex].g_flComboDeathRange[iPos], sSet[iPos], 0.0, 99999.0);
						g_esTank[iIndex].g_flComboDelay[iPos] = flGetClampedValue(key, "ComboDelay", "Combo Delay", "Combo_Delay", "delay", g_esTank[iIndex].g_flComboDelay[iPos], sSet[iPos], 0.0, 99999.0);
						g_esTank[iIndex].g_flComboDuration[iPos] = flGetClampedValue(key, "ComboDuration", "Combo Duration", "Combo_Duration", "duration", g_esTank[iIndex].g_flComboDuration[iPos], sSet[iPos], 0.0, 99999.0);
						g_esTank[iIndex].g_flComboInterval[iPos] = flGetClampedValue(key, "ComboInterval", "Combo Interval", "Combo_Interval", "interval", g_esTank[iIndex].g_flComboInterval[iPos], sSet[iPos], 0.0, 99999.0);
						g_esTank[iIndex].g_flComboRange[iPos] = flGetClampedValue(key, "ComboRange", "Combo Range", "Combo_Range", "range", g_esTank[iIndex].g_flComboRange[iPos], sSet[iPos], 0.0, 99999.0);
						g_esTank[iIndex].g_flComboRangeChance[iPos] = flGetClampedValue(key, "ComboRangeChance", "Combo Range Chance", "Combo_Range_Chance", "rangechance", g_esTank[iIndex].g_flComboRangeChance[iPos], sSet[iPos], 0.0, 100.0);
						g_esTank[iIndex].g_iComboRangeCooldown[iPos] = iGetClampedValue(key, "ComboRangeCooldown", "Combo Range Cooldown", "Combo_Range_Cooldown", "rangecooldown", g_esTank[iIndex].g_iComboRangeCooldown[iPos], sSet[iPos], 0, 99999);
						g_esTank[iIndex].g_flComboRockChance[iPos] = flGetClampedValue(key, "ComboRockChance", "Combo Rock Chance", "Combo_Rock_Chance", "rockchance", g_esTank[iIndex].g_flComboRockChance[iPos], sSet[iPos], 0.0, 100.0);
						g_esTank[iIndex].g_iComboRockCooldown[iPos] = iGetClampedValue(key, "ComboRockCooldown", "Combo Rock Cooldown", "Combo_Rock_Cooldown", "rockcooldown", g_esTank[iIndex].g_iComboRockCooldown[iPos], sSet[iPos], 0, 99999);
						g_esTank[iIndex].g_flComboSpeed[iPos] = flGetClampedValue(key, "ComboSpeed", "Combo Speed", "Combo_Speed", "speed", g_esTank[iIndex].g_flComboSpeed[iPos], sSet[iPos], 0.0, 99999.0);
					}
				}
			}
		}
		else if (StrEqual(sub, MT_CONFIG_SECTION_TRANSFORM, false))
		{
			if (StrEqual(key, "TransformTypes", false) || StrEqual(key, "Transform Types", false) || StrEqual(key, "Transform_Types", false) || StrEqual(key, "transtypes", false))
			{
				char sValue[50], sSet[10][5];
				strcopy(sValue, sizeof sValue, value);
				ReplaceString(sValue, sizeof sValue, " ", "");
				ExplodeString(sValue, ",", sSet, sizeof sSet, sizeof sSet[]);
				for (int iPos = 0; iPos < (sizeof esTank::g_iTransformType); iPos++)
				{
					g_esTank[iIndex].g_iTransformType[iPos] = (sSet[iPos][0] != '\0') ? iClamp(StringToInt(sSet[iPos]), 1, MT_MAXTYPES) : g_esTank[iIndex].g_iTransformType[iPos];
				}
			}
		}
		else if (StrEqual(sub, MT_CONFIG_SECTION_PROPS, false))
		{
			if (StrEqual(key, "PropsChance", false) || StrEqual(key, "Props Chance", false) || StrEqual(key, "Props_Chance", false) || StrEqual(key, "chance", false))
			{
				char sValue[54], sSet[9][6];
				strcopy(sValue, sizeof sValue, value);
				ReplaceString(sValue, sizeof sValue, " ", "");
				ExplodeString(sValue, ",", sSet, sizeof sSet, sizeof sSet[]);
				for (int iPos = 0; iPos < (sizeof esTank::g_flPropsChance); iPos++)
				{
					g_esTank[iIndex].g_flPropsChance[iPos] = (sSet[iPos][0] != '\0') ? flClamp(StringToFloat(sSet[iPos]), 0.0, 100.0) : g_esTank[iIndex].g_flPropsChance[iPos];
				}
			}
			else
			{
				char sValue[64], sSet[4][4];
				vGetConfigColors(sValue, sizeof sValue, value);
				vSaveConfigColors(key, "OxygenTankColor", "Oxygen Tank Color", "Oxygen_Tank_Color", "oxygen", g_esTank[iIndex].g_sOzTankColor, sizeof esTank::g_sOzTankColor, value);
				vSaveConfigColors(key, "FlameColor", "Flame Color", "Flame_Color", "flame", g_esTank[iIndex].g_sFlameColor, sizeof esTank::g_sFlameColor, value);
				vSaveConfigColors(key, "RockColor", "Rock Color", "Rock_Color", "rock", g_esTank[iIndex].g_sRockColor, sizeof esTank::g_sRockColor, value);
				vSaveConfigColors(key, "TireColor", "Tire Color", "Tire_Color", "tire", g_esTank[iIndex].g_sTireColor, sizeof esTank::g_sTireColor, value);
				vSaveConfigColors(key, "PropaneTankColor", "Propane Tank Color", "Propane_Tank_Color", "propane", g_esTank[iIndex].g_sPropTankColor, sizeof esTank::g_sPropTankColor, value);
				vSaveConfigColors(key, "FlashlightColor", "Flashlight Color", "Flashlight_Color", "flashlight", g_esTank[iIndex].g_sFlashlightColor, sizeof esTank::g_sFlashlightColor, value);
				ReplaceString(sValue, sizeof sValue, " ", "");
				ExplodeString(sValue, ",", sSet, sizeof sSet, sizeof sSet[]);

				for (int iPos = 0; iPos < (sizeof esTank::g_iLightColor); iPos++)
				{
					g_esTank[iIndex].g_iLightColor[iPos] = iGetClampedValue(key, "LightColor", "Light Color", "Light_Color", "light", g_esTank[iIndex].g_iLightColor[iPos], sSet[iPos], 0, 255, 0);
					g_esTank[iIndex].g_iOzTankColor[iPos] = iGetClampedValue(key, "OxygenTankColor", "Oxygen Tank Color", "Oxygen_Tank_Color", "oxygen", g_esTank[iIndex].g_iOzTankColor[iPos], sSet[iPos], 0, 255, 0);
					g_esTank[iIndex].g_iFlameColor[iPos] = iGetClampedValue(key, "FlameColor", "Flame Color", "Flame_Color", "flame", g_esTank[iIndex].g_iFlameColor[iPos], sSet[iPos], 0, 255, 0);
					g_esTank[iIndex].g_iRockColor[iPos] = iGetClampedValue(key, "RockColor", "Rock Color", "Rock_Color", "rock", g_esTank[iIndex].g_iRockColor[iPos], sSet[iPos], 0, 255, 0);
					g_esTank[iIndex].g_iTireColor[iPos] = iGetClampedValue(key, "TireColor", "Tire Color", "Tire_Color", "tire", g_esTank[iIndex].g_iTireColor[iPos], sSet[iPos], 0, 255, 0);
					g_esTank[iIndex].g_iPropTankColor[iPos] = iGetClampedValue(key, "PropaneTankColor", "Propane Tank Color", "Propane_Tank_Color", "propane", g_esTank[iIndex].g_iPropTankColor[iPos], sSet[iPos], 0, 255, 0);
					g_esTank[iIndex].g_iFlashlightColor[iPos] = iGetClampedValue(key, "FlashlightColor", "Flashlight Color", "Flashlight_Color", "flashlight", g_esTank[iIndex].g_iFlashlightColor[iPos], sSet[iPos], 0, 255, 0);
					g_esTank[iIndex].g_iCrownColor[iPos] = iGetClampedValue(key, "CrownColor", "Crown Color", "Crown_Color", "crown", g_esTank[iIndex].g_iCrownColor[iPos], sSet[iPos], 0, 255, 0);
				}
			}
		}

		if (g_esTank[iIndex].g_iAbilityCount == -1 && (StrContains(sub, "ability", false) != -1 || (((!strncmp(key, "ability", 7, false) && StrContains(key, "enabled", false) != -1) || StrEqual(key, "aenabled", false) || (StrContains(key, " hit", false) != -1 && StrContains(key, "mode", false) == -1) || StrEqual(key, "hit", false)) && StringToInt(value) > 0)))
		{
			g_esTank[iIndex].g_iAbilityCount = 0;
		}
		else if (g_esTank[iIndex].g_iAbilityCount != -1 && (bFoundSection(sub, 0) || bFoundSection(sub, 1) || bFoundSection(sub, 2) || bFoundSection(sub, 3))
			&& ((StrContains(key, "enabled", false) != -1 || (StrContains(key, " hit", false) != -1 && StrContains(key, "mode", false) == -1) || StrEqual(key, "hit", false)) && StringToInt(value) > 0))
		{
			g_esTank[iIndex].g_iAbilityCount++;
		}

		vConfigsLoadedForward(sub, key, value, iIndex, -1, g_esGeneral.g_iConfigMode);
	}
}

void vSaveConfigColors(const char[] key, const char[] setting1, const char[] setting2, const char[] setting3, const char[] setting4, char[] buffer, int size, const char[] value)
{
	if (StrEqual(key, setting1, false) || StrEqual(key, setting2, false) || StrEqual(key, setting3, false) || StrEqual(key, setting4, false))
	{
		strcopy(buffer, size, value);
	}
}

void vSetupConfigs()
{
	if (g_esGeneral.g_iConfigEnable == 1)
	{
		if (g_esGeneral.g_iConfigCreate & MT_CONFIG_DIFFICULTY)
		{
			char sSMPath[PLATFORM_MAX_PATH];
			BuildPath(Path_SM, sSMPath, sizeof sSMPath, "%s%s", MT_CONFIG_FILEPATH, MT_CONFIG_PATH_DIFFICULTY);
			CreateDirectory(sSMPath, 511);

			char sDifficulty[11];
			for (int iDifficulty = 0; iDifficulty <= 3; iDifficulty++)
			{
				switch (iDifficulty)
				{
					case 0: sDifficulty = "Easy";
					case 1: sDifficulty = "Normal";
					case 2: sDifficulty = "Hard";
					case 3: sDifficulty = "Impossible";
				}

				vCreateConfigFile(MT_CONFIG_FILEPATH ... MT_CONFIG_PATH_DIFFICULTY, sDifficulty);
			}
		}

		if (g_esGeneral.g_iConfigCreate & MT_CONFIG_MAP)
		{
			char sSMPath[PLATFORM_MAX_PATH];
			BuildPath(Path_SM, sSMPath, sizeof sSMPath, "%s%s", MT_CONFIG_FILEPATH, (g_bSecondGame ? MT_CONFIG_PATH_MAP2 : MT_CONFIG_PATH_MAP));
			CreateDirectory(sSMPath, 511);

			char sMapName[128];
			ArrayList alMaps = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
			if (alMaps != null)
			{
				int iSerial = -1;
				ReadMapList(alMaps, iSerial, "default", MAPLIST_FLAG_MAPSFOLDER);
				ReadMapList(alMaps, iSerial, "allexistingmaps__", MAPLIST_FLAG_MAPSFOLDER|MAPLIST_FLAG_NO_DEFAULT);

				int iListSize = alMaps.Length, iMapCount = (iListSize > 0) ? iListSize : 0;
				if (iMapCount > 0)
				{
					for (int iPos = 0; iPos < iMapCount; iPos++)
					{
						alMaps.GetString(iPos, sMapName, sizeof sMapName);
						vCreateConfigFile((g_bSecondGame ? (MT_CONFIG_FILEPATH ... MT_CONFIG_PATH_MAP2) : (MT_CONFIG_FILEPATH ... MT_CONFIG_PATH_MAP)), sMapName);
					}
				}

				delete alMaps;
			}
		}

		if (g_esGeneral.g_iConfigCreate & MT_CONFIG_GAMEMODE)
		{
			char sSMPath[PLATFORM_MAX_PATH];
			BuildPath(Path_SM, sSMPath, sizeof sSMPath, "%s%s", MT_CONFIG_FILEPATH, (g_bSecondGame ? MT_CONFIG_PATH_GAMEMODE2 : MT_CONFIG_PATH_GAMEMODE));
			CreateDirectory(sSMPath, 511);

			char sGameType[2049], sTypes[64][32];
			g_esGeneral.g_cvMTGameTypes.GetString(sGameType, sizeof sGameType);
			ReplaceString(sGameType, sizeof sGameType, " ", "");
			ExplodeString(sGameType, ",", sTypes, sizeof sTypes, sizeof sTypes[]);
			for (int iMode = 0; iMode < (sizeof sTypes); iMode++)
			{
				if (StrContains(sGameType, sTypes[iMode]) != -1 && sTypes[iMode][0] != '\0')
				{
					vCreateConfigFile((g_bSecondGame ? (MT_CONFIG_FILEPATH ... MT_CONFIG_PATH_GAMEMODE2) : (MT_CONFIG_FILEPATH ... MT_CONFIG_PATH_GAMEMODE)), sTypes[iMode]);
				}
			}
		}

		if (g_esGeneral.g_iConfigCreate & MT_CONFIG_DAY)
		{
			char sSMPath[PLATFORM_MAX_PATH];
			BuildPath(Path_SM, sSMPath, sizeof sSMPath, "%s%s", MT_CONFIG_FILEPATH, MT_CONFIG_PATH_DAY);
			CreateDirectory(sSMPath, 511);

			char sWeekday[32];
			for (int iDay = 0; iDay < 7; iDay++)
			{
				vGetDayName(iDay, sWeekday, sizeof sWeekday);
				vCreateConfigFile(MT_CONFIG_FILEPATH ... MT_CONFIG_PATH_DAY, sWeekday);
			}
		}

		if (g_esGeneral.g_iConfigCreate & MT_CONFIG_PLAYERCOUNT)
		{
			char sSMPath[PLATFORM_MAX_PATH];
			BuildPath(Path_SM, sSMPath, sizeof sSMPath, "%s%s", MT_CONFIG_FILEPATH, MT_CONFIG_PATH_PLAYERCOUNT);
			CreateDirectory(sSMPath, 511);

			char sPlayerCount[32];
			for (int iCount = 0; iCount <= (MAXPLAYERS + 1); iCount++)
			{
				IntToString(iCount, sPlayerCount, sizeof sPlayerCount);
				vCreateConfigFile(MT_CONFIG_FILEPATH ... MT_CONFIG_PATH_PLAYERCOUNT, sPlayerCount);
			}
		}

		if (g_esGeneral.g_iConfigCreate & MT_CONFIG_SURVIVORCOUNT)
		{
			char sSMPath[PLATFORM_MAX_PATH];
			BuildPath(Path_SM, sSMPath, sizeof sSMPath, "%s%s", MT_CONFIG_FILEPATH, MT_CONFIG_PATH_SURVIVORCOUNT);
			CreateDirectory(sSMPath, 511);

			char sPlayerCount[32];
			for (int iCount = 0; iCount <= (MAXPLAYERS + 1); iCount++)
			{
				IntToString(iCount, sPlayerCount, sizeof sPlayerCount);
				vCreateConfigFile(MT_CONFIG_FILEPATH ... MT_CONFIG_PATH_SURVIVORCOUNT, sPlayerCount);
			}
		}

		if (g_esGeneral.g_iConfigCreate & MT_CONFIG_INFECTEDCOUNT)
		{
			char sSMPath[PLATFORM_MAX_PATH];
			BuildPath(Path_SM, sSMPath, sizeof sSMPath, "%s%s", MT_CONFIG_FILEPATH, MT_CONFIG_PATH_INFECTEDCOUNT);
			CreateDirectory(sSMPath, 511);

			char sPlayerCount[32];
			for (int iCount = 0; iCount <= (MAXPLAYERS + 1); iCount++)
			{
				IntToString(iCount, sPlayerCount, sizeof sPlayerCount);
				vCreateConfigFile(MT_CONFIG_FILEPATH ... MT_CONFIG_PATH_INFECTEDCOUNT, sPlayerCount);
			}
		}

		if (g_esGeneral.g_iConfigCreate & MT_CONFIG_FINALE)
		{
			char sSMPath[PLATFORM_MAX_PATH];
			BuildPath(Path_SM, sSMPath, sizeof sSMPath, "%s%s", MT_CONFIG_FILEPATH, (g_bSecondGame ? MT_CONFIG_PATH_FINALE2 : MT_CONFIG_PATH_FINALE));
			CreateDirectory(sSMPath, 511);

			char sEvent[32];
			int iLimit = g_bSecondGame ? 11 : 8;
			for (int iType = 0; iType < iLimit; iType++)
			{
				switch (iType)
				{
					case 0: sEvent = "finale_start";
					case 1: sEvent = "finale_escape_start";
					case 2: sEvent = "finale_vehicle_ready";
					case 3: sEvent = "finale_vehicle_leaving";
					case 4: sEvent = "finale_rush";
					case 5: sEvent = "finale_radio_start";
					case 6: sEvent = "finale_radio_damaged";
					case 7: sEvent = "finale_win";
					case 8: sEvent = "finale_vehicle_incoming";
					case 9: sEvent = "finale_bridge_lowering";
					case 10: sEvent = "gauntlet_finale_start";
				}

				vCreateConfigFile((g_bSecondGame ? (MT_CONFIG_FILEPATH ... MT_CONFIG_PATH_FINALE2) : (MT_CONFIG_FILEPATH ... MT_CONFIG_PATH_FINALE)), sEvent);
			}
		}

		if ((g_esGeneral.g_iConfigExecute & MT_CONFIG_DIFFICULTY) && g_esGeneral.g_cvMTDifficulty != null)
		{
			char sDifficultyConfig[PLATFORM_MAX_PATH];
			if (bIsDifficultyConfigFound(sDifficultyConfig, sizeof sDifficultyConfig))
			{
				vCustomConfig(sDifficultyConfig);
				g_esGeneral.g_iFileTimeOld[1] = GetFileTime(sDifficultyConfig, FileTime_LastChange);
			}
		}

		if ((g_esGeneral.g_iConfigExecute & MT_CONFIG_MAP))
		{
			char sMapConfig[PLATFORM_MAX_PATH];
			if (bIsMapConfigFound(sMapConfig, sizeof sMapConfig))
			{
				vCustomConfig(sMapConfig);
				g_esGeneral.g_iFileTimeOld[2] = GetFileTime(sMapConfig, FileTime_LastChange);
			}
		}

		if (g_esGeneral.g_iConfigExecute & MT_CONFIG_GAMEMODE)
		{
			char sModeConfig[PLATFORM_MAX_PATH];
			if (bIsGameModeConfigFound(sModeConfig, sizeof sModeConfig))
			{
				vCustomConfig(sModeConfig);
				g_esGeneral.g_iFileTimeOld[3] = GetFileTime(sModeConfig, FileTime_LastChange);
			}
		}

		if (g_esGeneral.g_iConfigExecute & MT_CONFIG_DAY)
		{
			char sDayConfig[PLATFORM_MAX_PATH];
			if (bIsDayConfigFound(sDayConfig, sizeof sDayConfig))
			{
				vCustomConfig(sDayConfig);
				g_esGeneral.g_iFileTimeOld[4] = GetFileTime(sDayConfig, FileTime_LastChange);
			}
		}

		if (g_esGeneral.g_iConfigExecute & MT_CONFIG_PLAYERCOUNT)
		{
			char sCountConfig[PLATFORM_MAX_PATH];
			BuildPath(Path_SM, sCountConfig, sizeof sCountConfig, "%s%s%i.cfg", MT_CONFIG_FILEPATH, MT_CONFIG_PATH_PLAYERCOUNT, iGetPlayerCount());
			if (FileExists(sCountConfig, true))
			{
				vCustomConfig(sCountConfig);
				g_esGeneral.g_iFileTimeOld[5] = GetFileTime(sCountConfig, FileTime_LastChange);
			}
		}

		if (g_esGeneral.g_iConfigExecute & MT_CONFIG_SURVIVORCOUNT)
		{
			char sCountConfig[PLATFORM_MAX_PATH];
			BuildPath(Path_SM, sCountConfig, sizeof sCountConfig, "%s%s%i.cfg", MT_CONFIG_FILEPATH, MT_CONFIG_PATH_SURVIVORCOUNT, iGetHumanCount());
			if (FileExists(sCountConfig, true))
			{
				vCustomConfig(sCountConfig);
				g_esGeneral.g_iFileTimeOld[6] = GetFileTime(sCountConfig, FileTime_LastChange);
			}
		}

		if (g_esGeneral.g_iConfigExecute & MT_CONFIG_INFECTEDCOUNT)
		{
			char sCountConfig[PLATFORM_MAX_PATH];
			BuildPath(Path_SM, sCountConfig, sizeof sCountConfig, "%s%s%i.cfg", MT_CONFIG_FILEPATH, MT_CONFIG_PATH_INFECTEDCOUNT, iGetHumanCount(true));
			if (FileExists(sCountConfig, true))
			{
				vCustomConfig(sCountConfig);
				g_esGeneral.g_iFileTimeOld[7] = GetFileTime(sCountConfig, FileTime_LastChange);
			}
		}
	}
}

/**
 * Parser functions & callbacks
 **/

SMCParser smcSetupParser(const char[] savepath, SMC_ParseStart startFunc, SMC_NewSection newSectionFunc, SMC_KeyValue kvFunc, SMC_EndSection leaveSectionFunc, SMC_RawLine rawLineFunc, SMC_ParseEnd endFunc)
{
	SMCParser smcParser = new SMCParser();
	if (smcParser != null)
	{
		smcParser.OnStart = startFunc;
		smcParser.OnEnterSection = newSectionFunc;
		smcParser.OnKeyValue = kvFunc;
		smcParser.OnLeaveSection = leaveSectionFunc;
		smcParser.OnRawLine = rawLineFunc;
		smcParser.OnEnd = endFunc;
		SMCError smcError = smcParser.ParseFile(savepath);

		if (smcError != SMCError_Okay)
		{
			char sError[64], sSMCError[64];
			smcParser.GetErrorString(smcError, sError, sizeof sError);
			FormatEx(sSMCError, sizeof sSMCError, "(Line %i) %s", g_esGeneral.g_iCurrentLine, sError);
			LogError("%s %T", MT_TAG, "ErrorParsing", LANG_SERVER, savepath, sSMCError);

			delete smcParser;
		}
	}
	else
	{
		LogError("%s %T", MT_TAG, "FailedParsing", LANG_SERVER, savepath);
	}

	return smcParser;
}

void SMCParseStart_Signatures(SMCParser smc)
{
	g_esGeneral.g_dsState3 = DataState_None;
	g_esGeneral.g_iCurrentLine = 0;
	g_esGeneral.g_iIgnoreLevel5 = 0;
	g_esGeneral.g_sCurrentSection4[0] = '\0';
	g_esGeneral.g_iSignatureCount = 0;

	for (int iPos = 0; iPos < MT_SIGNATURE_LIMIT; iPos++)
	{
		g_esSignature[iPos].g_adString = Address_Null;
		g_esSignature[iPos].g_bLog = false;
		g_esSignature[iPos].g_sAfter[0] = '\0';
		g_esSignature[iPos].g_sBefore[0] = '\0';
		g_esSignature[iPos].g_sLibrary[0] = '\0';
		g_esSignature[iPos].g_sName[0] = '\0';
		g_esSignature[iPos].g_sOffset[0] = '\0';
		g_esSignature[iPos].g_sSignature[0] = '\0';
		g_esSignature[iPos].g_sStart[0] = '\0';
		g_esSignature[iPos].g_sdkLibrary = SDKLibrary_Server;
	}
}

SMCResult SMCNewSection_Signatures(SMCParser smc, const char[] name, bool opt_quotes)
{
	if (g_esGeneral.g_iIgnoreLevel5)
	{
		g_esGeneral.g_iIgnoreLevel5++;

		return SMCParse_Continue;
	}

	if (g_esGeneral.g_dsState3 == DataState_None)
	{
		switch (StrEqual(name, MT_SIGNATURES_SECTION_MAIN, false) || StrEqual(name, MT_SIGNATURES_SECTION_MAIN2, false) || StrEqual(name, MT_SIGNATURES_SECTION_MAIN3, false) || StrEqual(name, MT_SIGNATURES_SECTION_MAIN4, false) || StrEqual(name, MT_SIGNATURES_SECTION_MAIN5, false))
		{
			case true: g_esGeneral.g_dsState3 = DataState_Start;
			case false: g_esGeneral.g_iIgnoreLevel5++;
		}
	}
	else if (g_esGeneral.g_dsState3 == DataState_Start)
	{
		if ((!g_bSecondGame && (StrEqual(name, MT_DATA_SECTION_GAME, false) || StrEqual(name, MT_DATA_SECTION_GAME_ONE, false) || StrEqual(name, MT_DATA_SECTION_GAME2, false) || StrEqual(name, MT_DATA_SECTION_GAME_ONE2, false) || StrEqual(name, MT_DATA_SECTION_GAME3, false) || StrEqual(name, MT_DATA_SECTION_GAME_ONE3, false)
			|| StrEqual(name, MT_DATA_SECTION_GAME4, false) || StrEqual(name, MT_DATA_SECTION_GAME_ONE4, false))) || (g_bSecondGame && (StrEqual(name, MT_DATA_SECTION_GAME_TWO, false) || StrEqual(name, MT_DATA_SECTION_GAME_TWO2, false) || StrEqual(name, MT_DATA_SECTION_GAME_TWO3, false) || StrEqual(name, MT_DATA_SECTION_GAME_TWO4, false)))
			|| StrEqual(name, MT_DATA_SECTION_GAME_BOTH, false))
		{
			g_esGeneral.g_dsState3 = DataState_Game;

			strcopy(g_esGeneral.g_sCurrentSection4, sizeof esGeneral::g_sCurrentSection4, name);
		}
		else
		{
			g_esGeneral.g_iIgnoreLevel5++;
		}
	}
	else if (g_esGeneral.g_dsState3 == DataState_Game)
	{
		if (!strncmp(name, MT_SIGNATURES_SECTION_PREFIX, 12, false))
		{
			g_esGeneral.g_dsState3 = DataState_Name;

			strcopy(g_esGeneral.g_sCurrentSection4, sizeof esGeneral::g_sCurrentSection4, name);
			strcopy(g_esSignature[g_esGeneral.g_iSignatureCount].g_sName, sizeof esSignature::g_sName, name);
		}
		else
		{
			g_esGeneral.g_iIgnoreLevel5++;
		}
	}
	else
	{
		g_esGeneral.g_iIgnoreLevel5++;
	}

	return SMCParse_Continue;
}

SMCResult SMCKeyValues_Signatures(SMCParser smc, const char[] key, const char[] value, bool key_quotes, bool value_quotes)
{
	if (g_esGeneral.g_iIgnoreLevel5)
	{
		return SMCParse_Continue;
	}

	if (g_esGeneral.g_dsState3 == DataState_Name && !strncmp(g_esGeneral.g_sCurrentSection4, MT_SIGNATURES_SECTION_PREFIX, 12, false))
	{
		vReadSignatureSettings(key, value);
	}

	return SMCParse_Continue;
}

SMCResult SMCEndSection_Signatures(SMCParser smc)
{
	if (g_esGeneral.g_iIgnoreLevel5)
	{
		g_esGeneral.g_iIgnoreLevel5--;

		return SMCParse_Continue;
	}

	if (g_esGeneral.g_dsState3 == DataState_Name)
	{
		g_esGeneral.g_dsState3 = DataState_Game;

		vRegisterSignature(g_esSignature[g_esGeneral.g_iSignatureCount].g_sName);
	}
	else if (g_esGeneral.g_dsState3 == DataState_Game)
	{
		g_esGeneral.g_dsState3 = DataState_Start;
	}
	else if (g_esGeneral.g_dsState3 == DataState_Start)
	{
		g_esGeneral.g_dsState3 = DataState_None;
	}

	return SMCParse_Continue;
}

SMCResult SMCRawLine_Signatures(SMCParser smc, const char[] line, int lineno)
{
	g_esGeneral.g_iCurrentLine = lineno;

	return SMCParse_Continue;
}

void SMCParseEnd_Signatures(SMCParser smc, bool halted, bool failed)
{
	g_esGeneral.g_dsState3 = DataState_None;
	g_esGeneral.g_iIgnoreLevel5 = 0;
	g_esGeneral.g_sCurrentSection4[0] = '\0';

	vLogMessage(-1, _, "%s Registered %i signatures.", MT_TAG, g_esGeneral.g_iSignatureCount);
}

void SMCParseStart_Patches(SMCParser smc)
{
	g_esGeneral.g_bOverridePatch = true;
	g_esGeneral.g_dsState2 = DataState_None;
	g_esGeneral.g_iCurrentLine = 0;
	g_esGeneral.g_iIgnoreLevel4 = 0;
	g_esGeneral.g_sCurrentSection3[0] = '\0';
	g_esGeneral.g_sCurrentSubSection3[0] = '\0';
	g_esGeneral.g_iPatchCount = 0;

	for (int iPos = 0; iPos < MT_PATCH_LIMIT; iPos++)
	{
		g_esPatch[iPos].g_adPatch = Address_Null;
		g_esPatch[iPos].g_bInstalled = false;
		g_esPatch[iPos].g_bLog = false;
		g_esPatch[iPos].g_bUpdateMemAccess = true;
		g_esPatch[iPos].g_iLength = 0;
		g_esPatch[iPos].g_iOffset = 0;
		g_esPatch[iPos].g_iType = 0;
		g_esPatch[iPos].g_sBypass[0] = '\0';
		g_esPatch[iPos].g_sCvars[0] = '\0';
		g_esPatch[iPos].g_sName[0] = '\0';
		g_esPatch[iPos].g_sOffset[0] = '\0';
		g_esPatch[iPos].g_sPatch[0] = '\0';
		g_esPatch[iPos].g_sSignature[0] = '\0';
		g_esPatch[iPos].g_sVerify[0] = '\0';

		for (int iIndex = 0; iIndex < MT_PATCH_MAXLEN; iIndex++)
		{
			g_esPatch[iPos].g_iOriginalBytes[iIndex] = 0;
			g_esPatch[iPos].g_iPatchBytes[iIndex] = 0;
		}
	}
}

SMCResult SMCNewSection_Patches(SMCParser smc, const char[] name, bool opt_quotes)
{
	if (g_esGeneral.g_iIgnoreLevel4)
	{
		g_esGeneral.g_iIgnoreLevel4++;

		return SMCParse_Continue;
	}

	if (g_esGeneral.g_dsState2 == DataState_None)
	{
		switch (StrEqual(name, MT_PATCHES_SECTION_MAIN, false) || StrEqual(name, MT_PATCHES_SECTION_MAIN2, false) || StrEqual(name, MT_PATCHES_SECTION_MAIN3, false) || StrEqual(name, MT_PATCHES_SECTION_MAIN4, false) || StrEqual(name, MT_PATCHES_SECTION_MAIN5, false))
		{
			case true: g_esGeneral.g_dsState2 = DataState_Start;
			case false: g_esGeneral.g_iIgnoreLevel4++;
		}
	}
	else if (g_esGeneral.g_dsState2 == DataState_Start)
	{
		if ((!g_bSecondGame && (StrEqual(name, MT_DATA_SECTION_GAME, false) || StrEqual(name, MT_DATA_SECTION_GAME_ONE, false) || StrEqual(name, MT_DATA_SECTION_GAME2, false) || StrEqual(name, MT_DATA_SECTION_GAME_ONE2, false) || StrEqual(name, MT_DATA_SECTION_GAME3, false) || StrEqual(name, MT_DATA_SECTION_GAME_ONE3, false)
			|| StrEqual(name, MT_DATA_SECTION_GAME4, false) || StrEqual(name, MT_DATA_SECTION_GAME_ONE4, false))) || (g_bSecondGame && (StrEqual(name, MT_DATA_SECTION_GAME_TWO, false) || StrEqual(name, MT_DATA_SECTION_GAME_TWO2, false) || StrEqual(name, MT_DATA_SECTION_GAME_TWO3, false) || StrEqual(name, MT_DATA_SECTION_GAME_TWO4, false)))
			|| StrEqual(name, MT_DATA_SECTION_GAME_BOTH, false))
		{
			g_esGeneral.g_dsState2 = DataState_Game;

			strcopy(g_esGeneral.g_sCurrentSection3, sizeof esGeneral::g_sCurrentSection3, name);
		}
		else
		{
			g_esGeneral.g_iIgnoreLevel4++;
		}
	}
	else if (g_esGeneral.g_dsState2 == DataState_Game)
	{
		if (!strncmp(name, MT_PATCHES_SECTION_PREFIX, 8, false))
		{
			g_esGeneral.g_dsState2 = DataState_Name;

			strcopy(g_esGeneral.g_sCurrentSection3, sizeof esGeneral::g_sCurrentSection3, name);
			strcopy(g_esPatch[g_esGeneral.g_iPatchCount].g_sName, sizeof esPatch::g_sName, name);
		}
		else
		{
			g_esGeneral.g_iIgnoreLevel4++;
		}
	}
	else if (g_esGeneral.g_dsState2 == DataState_Name)
	{
		if ((g_esGeneral.g_iPlatformType == 2 && (StrEqual(name, MT_DATA_SECTION_OS, false) || StrEqual(name, MT_DATA_SECTION_OS2, false)))
			|| (g_esGeneral.g_iPlatformType == 1 && (StrEqual(name, MT_DATA_SECTION_OS3, false) || StrEqual(name, MT_DATA_SECTION_OS4, false)))
			|| (g_esGeneral.g_iPlatformType == 0 && (StrEqual(name, MT_DATA_SECTION_OS5, false) || StrEqual(name, MT_DATA_SECTION_OS6, false))))
		{
			g_esGeneral.g_dsState2 = DataState_OS;

			strcopy(g_esGeneral.g_sCurrentSubSection3, sizeof esGeneral::g_sCurrentSubSection3, name);
		}
		else
		{
			g_esGeneral.g_iIgnoreLevel4++;
		}
	}
	else
	{
		g_esGeneral.g_iIgnoreLevel4++;
	}

	return SMCParse_Continue;
}

SMCResult SMCKeyValues_Patches(SMCParser smc, const char[] key, const char[] value, bool key_quotes, bool value_quotes)
{
	if (g_esGeneral.g_iIgnoreLevel4)
	{
		return SMCParse_Continue;
	}

	if (g_esGeneral.g_dsState2 == DataState_Name && !strncmp(g_esGeneral.g_sCurrentSection3, MT_PATCHES_SECTION_PREFIX, 8, false))
	{
		vReadPatchSettings(key, value);
	}
	else if (g_esGeneral.g_dsState2 == DataState_OS
		&& ((g_esGeneral.g_iPlatformType == 2 && (StrEqual(g_esGeneral.g_sCurrentSubSection3, MT_DATA_SECTION_OS, false) || StrEqual(g_esGeneral.g_sCurrentSubSection3, MT_DATA_SECTION_OS2, false)))
			|| (g_esGeneral.g_iPlatformType == 1 && (StrEqual(g_esGeneral.g_sCurrentSubSection3, MT_DATA_SECTION_OS3, false) || StrEqual(g_esGeneral.g_sCurrentSubSection3, MT_DATA_SECTION_OS4, false)))
			|| (g_esGeneral.g_iPlatformType == 0 && (StrEqual(g_esGeneral.g_sCurrentSubSection3, MT_DATA_SECTION_OS5, false) || StrEqual(g_esGeneral.g_sCurrentSubSection3, MT_DATA_SECTION_OS6, false)))))
	{
		vReadPatchSettings(key, value);
	}

	return SMCParse_Continue;
}

SMCResult SMCEndSection_Patches(SMCParser smc)
{
	if (g_esGeneral.g_iIgnoreLevel4)
	{
		g_esGeneral.g_iIgnoreLevel4--;

		return SMCParse_Continue;
	}

	int iIndex = g_esGeneral.g_iPatchCount;
	if (g_esGeneral.g_dsState2 == DataState_OS)
	{
		g_esGeneral.g_dsState2 = DataState_Name;
		g_esGeneral.g_bOverridePatch = false;

		vRegisterPatch(g_esPatch[iIndex].g_sName, true);
	}
	else if (g_esGeneral.g_dsState2 == DataState_Name)
	{
		g_esGeneral.g_dsState2 = DataState_Game;
		iIndex = g_esGeneral.g_bOverridePatch ? iIndex : (iIndex - 1);

		vRegisterPatch(g_esPatch[iIndex].g_sName, g_esGeneral.g_bOverridePatch);
	}
	else if (g_esGeneral.g_dsState2 == DataState_Game)
	{
		g_esGeneral.g_dsState2 = DataState_Start;
	}
	else if (g_esGeneral.g_dsState2 == DataState_Start)
	{
		g_esGeneral.g_dsState2 = DataState_None;
	}

	return SMCParse_Continue;
}

SMCResult SMCRawLine_Patches(SMCParser smc, const char[] line, int lineno)
{
	g_esGeneral.g_iCurrentLine = lineno;

	return SMCParse_Continue;
}

void SMCParseEnd_Patches(SMCParser smc, bool halted, bool failed)
{
	g_esGeneral.g_dsState2 = DataState_None;
	g_esGeneral.g_iIgnoreLevel4 = 0;
	g_esGeneral.g_sCurrentSection3[0] = '\0';
	g_esGeneral.g_sCurrentSubSection3[0] = '\0';

	vLogMessage(-1, _, "%s Registered %i patches.", MT_TAG, g_esGeneral.g_iPatchCount);
}

void SMCParseStart_Detours(SMCParser smc)
{
	g_esGeneral.g_bOverrideDetour = true;
	g_esGeneral.g_dsState = DataState_None;
	g_esGeneral.g_iCurrentLine = 0;
	g_esGeneral.g_iIgnoreLevel3 = 0;
	g_esGeneral.g_sCurrentSection2[0] = '\0';
	g_esGeneral.g_sCurrentSubSection2[0] = '\0';
	g_esGeneral.g_iDetourCount = 0;

	for (int iPos = 0; iPos < MT_DETOUR_LIMIT; iPos++)
	{
		g_esDetour[iPos].g_bBypassNeeded = false;
		g_esDetour[iPos].g_bInstalled = false;
		g_esDetour[iPos].g_bLog = false;
		g_esDetour[iPos].g_iPostHook = 0;
		g_esDetour[iPos].g_iPreHook = 0;
		g_esDetour[iPos].g_iType = 0;
		g_esDetour[iPos].g_sCvars[0] = '\0';
		g_esDetour[iPos].g_sName[0] = '\0';
	}
}

SMCResult SMCNewSection_Detours(SMCParser smc, const char[] name, bool opt_quotes)
{
	if (g_esGeneral.g_iIgnoreLevel3)
	{
		g_esGeneral.g_iIgnoreLevel3++;

		return SMCParse_Continue;
	}

	if (g_esGeneral.g_dsState == DataState_None)
	{
		switch (StrEqual(name, MT_DETOURS_SECTION_MAIN, false) || StrEqual(name, MT_DETOURS_SECTION_MAIN2, false) || StrEqual(name, MT_DETOURS_SECTION_MAIN3, false) || StrEqual(name, MT_DETOURS_SECTION_MAIN4, false) || StrEqual(name, MT_DETOURS_SECTION_MAIN5, false))
		{
			case true: g_esGeneral.g_dsState = DataState_Start;
			case false: g_esGeneral.g_iIgnoreLevel3++;
		}
	}
	else if (g_esGeneral.g_dsState == DataState_Start)
	{
		if ((!g_bSecondGame && (StrEqual(name, MT_DATA_SECTION_GAME, false) || StrEqual(name, MT_DATA_SECTION_GAME_ONE, false) || StrEqual(name, MT_DATA_SECTION_GAME2, false) || StrEqual(name, MT_DATA_SECTION_GAME_ONE2, false) || StrEqual(name, MT_DATA_SECTION_GAME3, false) || StrEqual(name, MT_DATA_SECTION_GAME_ONE3, false)
			|| StrEqual(name, MT_DATA_SECTION_GAME4, false) || StrEqual(name, MT_DATA_SECTION_GAME_ONE4, false))) || (g_bSecondGame && (StrEqual(name, MT_DATA_SECTION_GAME_TWO, false) || StrEqual(name, MT_DATA_SECTION_GAME_TWO2, false) || StrEqual(name, MT_DATA_SECTION_GAME_TWO3, false) || StrEqual(name, MT_DATA_SECTION_GAME_TWO4, false)))
			|| StrEqual(name, MT_DATA_SECTION_GAME_BOTH, false))
		{
			g_esGeneral.g_dsState = DataState_Game;

			strcopy(g_esGeneral.g_sCurrentSection2, sizeof esGeneral::g_sCurrentSection2, name);
		}
		else
		{
			g_esGeneral.g_iIgnoreLevel3++;
		}
	}
	else if (g_esGeneral.g_dsState == DataState_Game)
	{
		if (!strncmp(name, MT_DETOURS_SECTION_PREFIX, 9, false))
		{
			g_esGeneral.g_dsState = DataState_Name;

			strcopy(g_esGeneral.g_sCurrentSection2, sizeof esGeneral::g_sCurrentSection2, name);
			strcopy(g_esDetour[g_esGeneral.g_iDetourCount].g_sName, sizeof esDetour::g_sName, name);
		}
		else
		{
			g_esGeneral.g_iIgnoreLevel3++;
		}
	}
	else if (g_esGeneral.g_dsState == DataState_Name)
	{
		if ((g_esGeneral.g_iPlatformType == 2 && (StrEqual(name, MT_DATA_SECTION_OS, false) || StrEqual(name, MT_DATA_SECTION_OS2, false)))
			|| (g_esGeneral.g_iPlatformType == 1 && (StrEqual(name, MT_DATA_SECTION_OS3, false) || StrEqual(name, MT_DATA_SECTION_OS4, false)))
			|| (g_esGeneral.g_iPlatformType == 0 && (StrEqual(name, MT_DATA_SECTION_OS5, false) || StrEqual(name, MT_DATA_SECTION_OS6, false))))
		{
			g_esGeneral.g_dsState = DataState_OS;

			strcopy(g_esGeneral.g_sCurrentSubSection2, sizeof esGeneral::g_sCurrentSubSection2, name);
		}
		else
		{
			g_esGeneral.g_iIgnoreLevel3++;
		}
	}
	else
	{
		g_esGeneral.g_iIgnoreLevel3++;
	}

	return SMCParse_Continue;
}

SMCResult SMCKeyValues_Detours(SMCParser smc, const char[] key, const char[] value, bool key_quotes, bool value_quotes)
{
	if (g_esGeneral.g_iIgnoreLevel3)
	{
		return SMCParse_Continue;
	}

	if (g_esGeneral.g_dsState == DataState_Name && !strncmp(g_esGeneral.g_sCurrentSection2, MT_DETOURS_SECTION_PREFIX, 9, false))
	{
		vReadDetourSettings(key, value);
	}
	else if (g_esGeneral.g_dsState == DataState_OS
		&& ((g_esGeneral.g_iPlatformType == 2 && (StrEqual(g_esGeneral.g_sCurrentSubSection2, MT_DATA_SECTION_OS, false) || StrEqual(g_esGeneral.g_sCurrentSubSection2, MT_DATA_SECTION_OS2, false)))
			|| (g_esGeneral.g_iPlatformType == 1 && (StrEqual(g_esGeneral.g_sCurrentSubSection2, MT_DATA_SECTION_OS3, false) || StrEqual(g_esGeneral.g_sCurrentSubSection2, MT_DATA_SECTION_OS4, false)))
			|| (g_esGeneral.g_iPlatformType == 0 && (StrEqual(g_esGeneral.g_sCurrentSubSection2, MT_DATA_SECTION_OS5, false) || StrEqual(g_esGeneral.g_sCurrentSubSection2, MT_DATA_SECTION_OS6, false)))))
	{
		vReadDetourSettings(key, value);
	}

	return SMCParse_Continue;
}

SMCResult SMCEndSection_Detours(SMCParser smc)
{
	if (g_esGeneral.g_iIgnoreLevel3)
	{
		g_esGeneral.g_iIgnoreLevel3--;

		return SMCParse_Continue;
	}

	int iIndex = g_esGeneral.g_iDetourCount;
	if (g_esGeneral.g_dsState == DataState_OS)
	{
		g_esGeneral.g_dsState = DataState_Name;
		g_esGeneral.g_bOverrideDetour = false;

		vRegisterDetour(g_esDetour[iIndex].g_sName, true);
	}
	else if (g_esGeneral.g_dsState == DataState_Name)
	{
		g_esGeneral.g_dsState = DataState_Game;
		iIndex = g_esGeneral.g_bOverrideDetour ? iIndex : (iIndex - 1);

		vRegisterDetour(g_esDetour[iIndex].g_sName, g_esGeneral.g_bOverrideDetour);
	}
	else if (g_esGeneral.g_dsState == DataState_Game)
	{
		g_esGeneral.g_dsState = DataState_Start;
	}
	else if (g_esGeneral.g_dsState == DataState_Start)
	{
		g_esGeneral.g_dsState = DataState_None;
	}

	return SMCParse_Continue;
}

SMCResult SMCRawLine_Detours(SMCParser smc, const char[] line, int lineno)
{
	g_esGeneral.g_iCurrentLine = lineno;

	return SMCParse_Continue;
}

void SMCParseEnd_Detours(SMCParser smc, bool halted, bool failed)
{
	g_esGeneral.g_dsState = DataState_None;
	g_esGeneral.g_iIgnoreLevel3 = 0;
	g_esGeneral.g_sCurrentSection2[0] = '\0';
	g_esGeneral.g_sCurrentSubSection2[0] = '\0';

	vLogMessage(-1, _, "%s Registered %i detours.", MT_TAG, g_esGeneral.g_iDetourCount);
}

void SMCParseStart_Config(SMCParser smc)
{
	g_esGeneral.g_iCurrentLine = 0;
}

SMCResult SMCNewSection_Config(SMCParser smc, const char[] name, bool opt_quotes)
{
	if (StrEqual(name, MT_CONFIG_SECTION_MAIN, false) || StrEqual(name, MT_CONFIG_SECTION_MAIN2, false) || StrEqual(name, MT_CONFIG_SECTION_MAIN3, false) || StrEqual(name, MT_CONFIG_SECTION_MAIN4, false) || StrEqual(name, MT_CONFIG_SECTION_MAIN5, false))
	{
		return SMCParse_Continue;
	}

	if (StrEqual(name, MT_CONFIG_SECTION_SETTINGS, false) || StrEqual(name, MT_CONFIG_SECTION_SETTINGS2, false) || StrEqual(name, MT_CONFIG_SECTION_SETTINGS3, false) || StrEqual(name, MT_CONFIG_SECTION_SETTINGS4, false) || !strncmp(name, "STEAM_", 6, false)
		|| !strncmp("0:", name, 2) || !strncmp("1:", name, 2) || (!strncmp(name, "[U:", 3) && name[strlen(name) - 1] == ']') || StrContains(name, "all", false) != -1 || FindCharInString(name, ',') != -1 || FindCharInString(name, '-') != -1
		|| !strncmp(name, "Tank", 4, false) || name[0] == '#' || IsCharNumeric(name[0]))
	{
		g_esGeneral.g_alSections.PushString(name);
	}

	return SMCParse_Continue;
}

SMCResult SMCKeyValues_Config(SMCParser smc, const char[] key, const char[] value, bool key_quotes, bool value_quotes)
{
	return SMCParse_Continue;
}

SMCResult SMCEndSection_Config(SMCParser smc)
{
	return SMCParse_Continue;
}

SMCResult SMCRawLine_Config(SMCParser smc, const char[] line, int lineno)
{
	g_esGeneral.g_iCurrentLine = lineno;

	return SMCParse_Continue;
}

void SMCParseEnd_Config(SMCParser smc, bool halted, bool failed)
{
	return;
}

void vParseConfig(int client)
{
	g_esGeneral.g_bUsedParser = true;
	g_esGeneral.g_iParserViewer = client;

	SMCParser smcParser = smcSetupParser(g_esGeneral.g_sChosenPath, SMCParseStart_Parser, SMCNewSection_Parser, SMCKeyValues_Parser, SMCEndSection_Parser, SMCRawLine_Parser, SMCParseEnd_Parser);
	if (smcParser != null)
	{
		delete smcParser;
	}
}

void SMCParseStart_Parser(SMCParser smc)
{
	g_esGeneral.g_csState2 = ConfigState_None;
	g_esGeneral.g_iCurrentLine = 0;
	g_esGeneral.g_iIgnoreLevel2 = 0;

	switch (bIsValidClient(g_esGeneral.g_iParserViewer, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT))
	{
		case true: MT_PrintToChat(g_esGeneral.g_iParserViewer, "%s %t", MT_TAG2, "StartParsing");
		case false: vLogMessage(MT_LOG_SERVER, _, "%s %T", MT_TAG, "StartParsing", LANG_SERVER);
	}
}

SMCResult SMCNewSection_Parser(SMCParser smc, const char[] name, bool opt_quotes)
{
	if (g_esGeneral.g_iIgnoreLevel2)
	{
		g_esGeneral.g_iIgnoreLevel2++;

		return SMCParse_Continue;
	}

	bool bHuman = bIsValidClient(g_esGeneral.g_iParserViewer, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT);
	if (g_esGeneral.g_csState2 == ConfigState_None)
	{
		if (StrEqual(name, MT_CONFIG_SECTION_MAIN, false) || StrEqual(name, MT_CONFIG_SECTION_MAIN2, false) || StrEqual(name, MT_CONFIG_SECTION_MAIN3, false) || StrEqual(name, MT_CONFIG_SECTION_MAIN4, false) || StrEqual(name, MT_CONFIG_SECTION_MAIN5, false))
		{
			g_esGeneral.g_csState2 = ConfigState_Start;

			switch (bHuman)
			{
				case true: MT_PrintToChat(g_esGeneral.g_iParserViewer, (opt_quotes) ? ("\"%s\"\n{") : ("%s\n{"), name);
				case false: vLogMessage(MT_LOG_SERVER, false, (opt_quotes) ? ("\"%s\"\n{") : ("%s\n{"), name);
			}
		}
		else
		{
			g_esGeneral.g_iIgnoreLevel2++;
		}
	}
	else if (g_esGeneral.g_csState2 == ConfigState_Start)
	{
		if ((StrEqual(name, MT_CONFIG_SECTION_SETTINGS, false) || StrEqual(name, MT_CONFIG_SECTION_SETTINGS2, false) || StrEqual(name, MT_CONFIG_SECTION_SETTINGS3, false) || StrEqual(name, MT_CONFIG_SECTION_SETTINGS4, false)) && StrContains(name, g_esGeneral.g_sSection, false) != -1)
		{
			g_esGeneral.g_csState2 = ConfigState_Settings;

			switch (bHuman)
			{
				case true: MT_PrintToChat(g_esGeneral.g_iParserViewer, (opt_quotes) ? ("%7s \"%s\"\n%7s {") : ("%7s %s\n%7s {"), "", name, "");
				case false: vLogMessage(MT_LOG_SERVER, false, (opt_quotes) ? ("%7s \"%s\"\n%7s {") : ("%7s %s\n%7s {"), "", name, "");
			}
		}
		else if (g_esGeneral.g_iSection > 0 && (!strncmp(name, "Tank", 4, false) || name[0] == '#' || IsCharNumeric(name[0]) || StrContains(name, "all", false) != -1 || FindCharInString(name, ',') != -1 || FindCharInString(name, '-') != -1))
		{
			char sSection[33], sIndex[5], sType[5];
			strcopy(sSection, sizeof sSection, name);

			int iIndex = iFindSectionType(name, g_esGeneral.g_iSection), iStartPos = iGetConfigSectionNumber(sSection, sizeof sSection);
			IntToString(iIndex, sIndex, sizeof sIndex);
			IntToString(g_esGeneral.g_iSection, sType, sizeof sType);
			if (StrContains(name, sType) != -1 && (StrEqual(sType, sSection[iStartPos]) || StrEqual(sType, sIndex) || StrContains(name, "all", false) != -1))
			{
				g_esGeneral.g_csState2 = ConfigState_Type;

				switch (bHuman)
				{
					case true: MT_PrintToChat(g_esGeneral.g_iParserViewer, (opt_quotes) ? ("%7s \"%s\"\n%7s {") : ("%7s %s\n%7s {"), "", name, "");
					case false: vLogMessage(MT_LOG_SERVER, false, (opt_quotes) ? ("%7s \"%s\"\n%7s {") : ("%7s %s\n%7s {"), "", name, "");
				}
			}
			else
			{
				g_esGeneral.g_iIgnoreLevel2++;
			}
		}
		else if (StrEqual(name, g_esGeneral.g_sSection, false) && (StrContains(name, "all", false) != -1 || FindCharInString(name, ',') != -1 || FindCharInString(name, '-') != -1))
		{
			g_esGeneral.g_csState2 = ConfigState_Type;

			switch (bHuman)
			{
				case true: MT_PrintToChat(g_esGeneral.g_iParserViewer, (opt_quotes) ? ("%7s \"%s\"\n%7s {") : ("%7s %s\n%7s {"), "", name, "");
				case false: vLogMessage(MT_LOG_SERVER, false, (opt_quotes) ? ("%7s \"%s\"\n%7s {") : ("%7s %s\n%7s {"), "", name, "");
			}
		}
		else if ((!strncmp(name, "STEAM_", 6, false) || !strncmp("0:", name, 2) || !strncmp("1:", name, 2) || (!strncmp(name, "[U:", 3) && name[strlen(name) - 1] == ']')) && StrContains(name, g_esGeneral.g_sSection, false) != -1)
		{
			g_esGeneral.g_csState2 = ConfigState_Admin;

			switch (bHuman)
			{
				case true: MT_PrintToChat(g_esGeneral.g_iParserViewer, (opt_quotes) ? ("%7s \"%s\"\n%7s {") : ("%7s %s\n%7s {"), "", name, "");
				case false: vLogMessage(MT_LOG_SERVER, false, (opt_quotes) ? ("%7s \"%s\"\n%7s {") : ("%7s %s\n%7s {"), "", name, "");
			}
		}
		else
		{
			g_esGeneral.g_iIgnoreLevel2++;
		}
	}
	else if (g_esGeneral.g_csState2 == ConfigState_Settings || g_esGeneral.g_csState2 == ConfigState_Type || g_esGeneral.g_csState2 == ConfigState_Admin)
	{
		g_esGeneral.g_csState2 = ConfigState_Specific;

		switch (bHuman)
		{
			case true: MT_PrintToChat(g_esGeneral.g_iParserViewer, (opt_quotes) ? ("%15s \"%s\"\n%15s {") : ("%15s %s\n%15s {"), "", name, "");
			case false: vLogMessage(MT_LOG_SERVER, false, (opt_quotes) ? ("%15s \"%s\"\n%15s {") : ("%15s %s\n%15s {"), "", name, "");
		}
	}
	else
	{
		g_esGeneral.g_iIgnoreLevel2++;
	}

	return SMCParse_Continue;
}

SMCResult SMCKeyValues_Parser(SMCParser smc, const char[] key, const char[] value, bool key_quotes, bool value_quotes)
{
	if (g_esGeneral.g_iIgnoreLevel2)
	{
		return SMCParse_Continue;
	}

	if (g_esGeneral.g_csState2 == ConfigState_Specific)
	{
		char sKey[64], sValue[384];
		FormatEx(sKey, sizeof sKey, (key_quotes ? "\"%s\"" : "%s"), key);
		FormatEx(sValue, sizeof sValue, (value_quotes ? "\"%s\"" : "%s"), value);

		switch (bIsValidClient(g_esGeneral.g_iParserViewer, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT))
		{
			case true: MT_PrintToChat(g_esGeneral.g_iParserViewer, "%23s %39s %s", "", sKey, (value[0] == '\0') ? "\"\"" : sValue);
			case false: vLogMessage(MT_LOG_SERVER, false, "%23s %39s %s", "", sKey, (value[0] == '\0') ? "\"\"" : sValue);
		}
	}

	return SMCParse_Continue;
}

SMCResult SMCEndSection_Parser(SMCParser smc)
{
	if (g_esGeneral.g_iIgnoreLevel2)
	{
		g_esGeneral.g_iIgnoreLevel2--;

		return SMCParse_Continue;
	}

	bool bHuman = bIsValidClient(g_esGeneral.g_iParserViewer, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT);
	if (g_esGeneral.g_csState2 == ConfigState_Specific)
	{
		if (StrContains(MT_CONFIG_SECTION_SETTINGS, g_esGeneral.g_sSection, false) != -1 || StrContains(MT_CONFIG_SECTION_SETTINGS2, g_esGeneral.g_sSection, false) != -1 || StrContains(MT_CONFIG_SECTION_SETTINGS3, g_esGeneral.g_sSection, false) != -1 || StrContains(MT_CONFIG_SECTION_SETTINGS4, g_esGeneral.g_sSection, false) != -1)
		{
			g_esGeneral.g_csState2 = ConfigState_Settings;

			switch (bHuman)
			{
				case true: MT_PrintToChat(g_esGeneral.g_iParserViewer, "%15s }", "");
				case false: vLogMessage(MT_LOG_SERVER, false, "%15s }", "");
			}
		}
		else if (g_esGeneral.g_iSection > 0 && (!strncmp(g_esGeneral.g_sSection, "Tank", 4, false) || g_esGeneral.g_sSection[0] == '#' || IsCharNumeric(g_esGeneral.g_sSection[0]) || StrContains(g_esGeneral.g_sSection, "all", false) != -1 || FindCharInString(g_esGeneral.g_sSection, ',') != -1 || FindCharInString(g_esGeneral.g_sSection, '-') != -1))
		{
			g_esGeneral.g_csState2 = ConfigState_Type;

			switch (bHuman)
			{
				case true: MT_PrintToChat(g_esGeneral.g_iParserViewer, "%15s }", "");
				case false: vLogMessage(MT_LOG_SERVER, false, "%15s }", "");
			}
		}
		else if (StrContains(g_esGeneral.g_sSection, "all", false) != -1 || FindCharInString(g_esGeneral.g_sSection, ',') != -1 || FindCharInString(g_esGeneral.g_sSection, '-') != -1)
		{
			g_esGeneral.g_csState2 = ConfigState_Type;

			switch (bHuman)
			{
				case true: MT_PrintToChat(g_esGeneral.g_iParserViewer, "%15s }", "");
				case false: vLogMessage(MT_LOG_SERVER, false, "%15s }", "");
			}
		}
		else if (!strncmp(g_esGeneral.g_sSection, "STEAM_", 6, false) || !strncmp("0:", g_esGeneral.g_sSection, 2) || !strncmp("1:", g_esGeneral.g_sSection, 2) || (!strncmp(g_esGeneral.g_sSection, "[U:", 3) && g_esGeneral.g_sSection[strlen(g_esGeneral.g_sSection) - 1] == ']'))
		{
			g_esGeneral.g_csState2 = ConfigState_Admin;

			switch (bHuman)
			{
				case true: MT_PrintToChat(g_esGeneral.g_iParserViewer, "%15s }", "");
				case false: vLogMessage(MT_LOG_SERVER, false, "%15s }", "");
			}
		}
	}
	else if (g_esGeneral.g_csState2 == ConfigState_Settings || g_esGeneral.g_csState2 == ConfigState_Type || g_esGeneral.g_csState2 == ConfigState_Admin)
	{
		g_esGeneral.g_csState2 = ConfigState_Start;

		switch (bHuman)
		{
			case true: MT_PrintToChat(g_esGeneral.g_iParserViewer, "%7s }", "");
			case false: vLogMessage(MT_LOG_SERVER, false, "%7s }", "");
		}
	}
	else if (g_esGeneral.g_csState2 == ConfigState_Start)
	{
		g_esGeneral.g_csState2 = ConfigState_None;

		switch (bHuman)
		{
			case true: MT_PrintToChat(g_esGeneral.g_iParserViewer, "}");
			case false: vLogMessage(MT_LOG_SERVER, false, "}");
		}
	}

	return SMCParse_Continue;
}

SMCResult SMCRawLine_Parser(SMCParser smc, const char[] line, int lineno)
{
	g_esGeneral.g_iCurrentLine = lineno;

	return SMCParse_Continue;
}

void SMCParseEnd_Parser(SMCParser smc, bool halted, bool failed)
{
	switch (bIsValidClient(g_esGeneral.g_iParserViewer, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT))
	{
		case true: MT_PrintToChat(g_esGeneral.g_iParserViewer, "\n\n\n\n\n\n%s %t\n%s %t", MT_TAG2, "CompletedParsing", MT_TAG2, "CheckConsole");
		case false: vLogMessage(MT_LOG_SERVER, _, "%s %T", MT_TAG, "CompletedParsing", LANG_SERVER);
	}

	g_esGeneral.g_bUsedParser = false;
	g_esGeneral.g_csState2 = ConfigState_None;
	g_esGeneral.g_iIgnoreLevel2 = 0;
	g_esGeneral.g_iParserViewer = 0;
	g_esGeneral.g_iSection = 0;
	g_esGeneral.g_sSection[0] = '\0';
}

void vConfigsLoadedForward(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
{
	Call_StartForward(g_esGeneral.g_gfConfigsLoadedForward);
	Call_PushString(subsection);
	Call_PushString(key);
	Call_PushString(value);
	Call_PushCell(type);
	Call_PushCell(admin);
	Call_PushCell(mode);
	Call_Finish();
}

void vLoadConfigs(const char[] savepath, int mode)
{
	vClearAbilityList();
	vClearColorKeysList();
	vClearPluginList();

	g_esGeneral.g_alColorKeys[0] = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
	g_esGeneral.g_alColorKeys[1] = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));

	g_esGeneral.g_alPlugins = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
	if (g_esGeneral.g_alPlugins != null)
	{
		Call_StartForward(g_esGeneral.g_gfPluginCheckForward);
		Call_PushCell(g_esGeneral.g_alPlugins);
		Call_Finish();
	}

	bool bFinish = true;
	Call_StartForward(g_esGeneral.g_gfAbilityCheckForward);

	for (int iPos = 0; iPos < (sizeof esGeneral::g_alAbilitySections); iPos++)
	{
		g_esGeneral.g_alAbilitySections[iPos] = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));

		switch (g_esGeneral.g_alAbilitySections[iPos] != null)
		{
			case true: Call_PushCell(g_esGeneral.g_alAbilitySections[iPos]);
			case false:
			{
				bFinish = false;

				Call_Cancel();

				break;
			}
		}
	}

	if (bFinish)
	{
		Call_Finish();
	}

	for (int iPos = 0; iPos < MT_MAXABILITIES; iPos++)
	{
		g_esGeneral.g_bAbilityPlugin[iPos] = false;
	}

	if (g_esGeneral.g_alPlugins != null)
	{
		int iLength = g_esGeneral.g_alPlugins.Length, iListSize = (iLength > 0) ? iLength : 0;
		if (iListSize > 0)
		{
			for (int iPos = 0; iPos < iListSize; iPos++)
			{
				g_esGeneral.g_bAbilityPlugin[iPos] = true;
			}
		}
	}

	g_esGeneral.g_iConfigMode = mode;

	if (g_esGeneral.g_alFilePaths != null)
	{
		int iLength = g_esGeneral.g_alFilePaths.Length, iListSize = (iLength > 0) ? iLength : 0;
		if (iListSize > 0)
		{
			bool bAdd = true;
			char sFilePath[PLATFORM_MAX_PATH];
			for (int iPos = 0; iPos < iListSize; iPos++)
			{
				g_esGeneral.g_alFilePaths.GetString(iPos, sFilePath, sizeof sFilePath);
				if (StrEqual(savepath, sFilePath, false))
				{
					bAdd = false;

					break;
				}
			}

			if (bAdd)
			{
				g_esGeneral.g_alFilePaths.PushString(savepath);
			}
		}
		else
		{
			g_esGeneral.g_alFilePaths.PushString(savepath);
		}
	}

	SMCParser smcMain = smcSetupParser(savepath, SMCParseStart_Main, SMCNewSection_Main, SMCKeyValues_Main, SMCEndSection_Main, SMCRawLine_Main, SMCParseEnd_Main);
	if (smcMain != null)
	{
		delete smcMain;
	}
}

void SMCParseStart_Main(SMCParser smc)
{
	g_esGeneral.g_csState = ConfigState_None;
	g_esGeneral.g_iCurrentLine = 0;
	g_esGeneral.g_iIgnoreLevel = 0;
	g_esGeneral.g_iTypeCounter[0] = 0;
	g_esGeneral.g_iTypeCounter[1] = 0;
	g_esGeneral.g_sCurrentSection[0] = '\0';
	g_esGeneral.g_sCurrentSubSection[0] = '\0';

	if (g_esGeneral.g_iConfigMode == 1)
	{
		g_esGeneral.g_iPluginEnabled = 0;
		g_esGeneral.g_iAutoUpdate = 0;
		g_esGeneral.g_iListenSupport = g_bDedicated ? 0 : 1;
		g_esGeneral.g_iCheckAbilities = 1;
		g_esGeneral.g_iDeathRevert = 1;
		g_esGeneral.g_iFinalesOnly = 0;
		g_esGeneral.g_flIdleCheck = 10.0;
		g_esGeneral.g_iIdleCheckMode = 2;
		g_esGeneral.g_iLogCommands = 31;
		g_esGeneral.g_iLogMessages = 0;
		g_esGeneral.g_iTankEnabled = -1;
		g_esGeneral.g_iTankModel = 0;
		g_esGeneral.g_flBurnDuration = 0.0;
		g_esGeneral.g_flBurntSkin = -1.0;
		g_esGeneral.g_iSpawnEnabled = -1;
		g_esGeneral.g_iSpawnLimit = 0;
		g_esGeneral.g_iMinType = 1;
		g_esGeneral.g_iMaxType = MT_MAXTYPES;
		g_esGeneral.g_iRequiresHumans = 0;
		g_esGeneral.g_iAnnounceArrival = 31;
		g_esGeneral.g_iAnnounceDeath = 1;
		g_esGeneral.g_iAnnounceKill = 1;
		g_esGeneral.g_iArrivalMessage = 0;
		g_esGeneral.g_iArrivalSound = 1;
		g_esGeneral.g_iDeathDetails = 5;
		g_esGeneral.g_iDeathMessage = 0;
		g_esGeneral.g_iDeathSound = 1;
		g_esGeneral.g_iKillMessage = 0;
		g_esGeneral.g_iVocalizeArrival = 1;
		g_esGeneral.g_iVocalizeDeath = 1;
		g_esGeneral.g_sBodyColorVisual = "-1;-1;-1;-1";
		g_esGeneral.g_sBodyColorVisual2 = "-1;-1;-1;-1";
		g_esGeneral.g_sBodyColorVisual3 = "-1;-1;-1;-1";
		g_esGeneral.g_sBodyColorVisual4 = "-1;-1;-1;-1";
		g_esGeneral.g_sFallVoicelineReward = "PlayerLaugh";
		g_esGeneral.g_sFallVoicelineReward2 = "PlayerLaugh";
		g_esGeneral.g_sFallVoicelineReward3 = "PlayerLaugh";
		g_esGeneral.g_sFallVoicelineReward4 = "PlayerLaugh";
		g_esGeneral.g_sItemReward = "first_aid_kit";
		g_esGeneral.g_sItemReward2 = "first_aid_kit";
		g_esGeneral.g_sItemReward3 = "first_aid_kit";
		g_esGeneral.g_sItemReward4 = "first_aid_kit";
		g_esGeneral.g_sLightColorVisual = "-1;-1;-1;-1";
		g_esGeneral.g_sLightColorVisual2 = "-1;-1;-1;-1";
		g_esGeneral.g_sLightColorVisual3 = "-1;-1;-1;-1";
		g_esGeneral.g_sLightColorVisual4 = "-1;-1;-1;-1";
		g_esGeneral.g_sLoopingVoicelineVisual = "PlayerDeath";
		g_esGeneral.g_sLoopingVoicelineVisual2 = "PlayerDeath";
		g_esGeneral.g_sLoopingVoicelineVisual3 = "PlayerDeath";
		g_esGeneral.g_sLoopingVoicelineVisual4 = "PlayerDeath";
		g_esGeneral.g_sOutlineColorVisual = "-1;-1;-1";
		g_esGeneral.g_sOutlineColorVisual2 = "-1;-1;-1";
		g_esGeneral.g_sOutlineColorVisual3 = "-1;-1;-1";
		g_esGeneral.g_sOutlineColorVisual4 = "-1;-1;-1";
		g_esGeneral.g_sScreenColorVisual = "-1;-1;-1;-1";
		g_esGeneral.g_sScreenColorVisual2 = "-1;-1;-1;-1";
		g_esGeneral.g_sScreenColorVisual3 = "-1;-1;-1;-1";
		g_esGeneral.g_sScreenColorVisual4 = "-1;-1;-1;-1";
		g_esGeneral.g_iTeammateLimit = 0;
		g_esGeneral.g_iAutoAggravate = 1;
		g_esGeneral.g_iCreditIgniters = 1;
		g_esGeneral.g_flForceSpawn = 0.0;
		g_esGeneral.g_iStasisMode = 0;
		g_esGeneral.g_flSurvivalDelay = 0.1;
		g_esGeneral.g_iScaleDamage = 0;
		g_esGeneral.g_iBaseHealth = 0;
		g_esGeneral.g_iDisplayHealth = 11;
		g_esGeneral.g_iDisplayHealthType = 1;
		g_esGeneral.g_iExtraHealth = 0;
		g_esGeneral.g_sHealthCharacters = "|,-";
		g_esGeneral.g_flHealPercentMultiplier = 1.0;
		g_esGeneral.g_iHumanMultiplierMode = 0;
		g_esGeneral.g_iMinimumHumans = 2;
		g_esGeneral.g_iMultiplyHealth = 0;
		g_esGeneral.g_flAttackInterval = 0.0;
		g_esGeneral.g_flClawDamage = -1.0;
		g_esGeneral.g_iGroundPound = 0;
		g_esGeneral.g_flHittableDamage = -1.0;
		g_esGeneral.g_flIncapDamageMultiplier = 1.0;
		g_esGeneral.g_flPunchForce = -1.0;
		g_esGeneral.g_flPunchThrow = 0.0;
		g_esGeneral.g_flRockDamage = -1.0;
		g_esGeneral.g_iRockSound = 0;
		g_esGeneral.g_flRunSpeed = 0.0;
		g_esGeneral.g_iSkipIncap = 0;
		g_esGeneral.g_iSkipTaunt = 0;
		g_esGeneral.g_iSweepFist = 0;
		g_esGeneral.g_flThrowInterval = 0.0;
		g_esGeneral.g_iBulletImmunity = 0;
		g_esGeneral.g_iExplosiveImmunity = 0;
		g_esGeneral.g_iFireImmunity = 0;
		g_esGeneral.g_iHittableImmunity = 0;
		g_esGeneral.g_iMeleeImmunity = 0;
		g_esGeneral.g_iVomitImmunity = 0;
		g_esGeneral.g_iAccessFlags = 0;
		g_esGeneral.g_iImmunityFlags = 0;
		g_esGeneral.g_iHumanCooldown = 600;
		g_esGeneral.g_iMasterControl = 0;
		g_esGeneral.g_iSpawnMode = 2;
		g_esGeneral.g_iLimitExtras = 1;
		g_esGeneral.g_flExtrasDelay = 0.1;
		g_esGeneral.g_iRegularAmount = 0;
		g_esGeneral.g_flRegularDelay = 10.0;
		g_esGeneral.g_flRegularInterval = 300.0;
		g_esGeneral.g_iRegularLimit = 99999;
		g_esGeneral.g_iRegularMinType = 1;
		g_esGeneral.g_iRegularMaxType = MT_MAXTYPES;
		g_esGeneral.g_iRegularMode = 0;
		g_esGeneral.g_iRegularWave = 0;
		g_esGeneral.g_iFinaleAmount = 0;
		g_esGeneral.g_iGameModeTypes = 0;
		g_esGeneral.g_sEnabledGameModes[0] = '\0';
		g_esGeneral.g_sDisabledGameModes[0] = '\0';
		g_esGeneral.g_iConfigEnable = 0;
		g_esGeneral.g_iConfigCreate = 0;
		g_esGeneral.g_flConfigDelay = 5.0;
		g_esGeneral.g_iConfigExecute = 0;

		for (int iPos = 0; iPos < (sizeof esGeneral::g_iFinaleWave); iPos++)
		{
			g_esGeneral.g_iFinaleMaxTypes[iPos] = MT_MAXTYPES;
			g_esGeneral.g_iFinaleMinTypes[iPos] = 1;
			g_esGeneral.g_iFinaleWave[iPos] = 0;

			if (iPos < (sizeof esGeneral::g_iRewardEnabled))
			{
				g_esGeneral.g_iRewardEnabled[iPos] = -1;
				g_esGeneral.g_iRewardBots[iPos] = -1;
				g_esGeneral.g_flRewardChance[iPos] = 33.3;
				g_esGeneral.g_flRewardDuration[iPos] = 10.0;
				g_esGeneral.g_iRewardEffect[iPos] = 15;
				g_esGeneral.g_iRewardNotify[iPos] = 3;
				g_esGeneral.g_flRewardPercentage[iPos] = 10.0;
				g_esGeneral.g_iRewardVisual[iPos] = 63;
				g_esGeneral.g_flActionDurationReward[iPos] = 2.0;
				g_esGeneral.g_iAmmoBoostReward[iPos] = 1;
				g_esGeneral.g_iAmmoRegenReward[iPos] = 1;
				g_esGeneral.g_flAttackBoostReward[iPos] = 1.25;
				g_esGeneral.g_iBunnyHopReward[iPos] = 1;
				g_esGeneral.g_iBurstDoorsReward[iPos] = 1;
				g_esGeneral.g_iCleanKillsReward[iPos] = 1;
				g_esGeneral.g_flDamageBoostReward[iPos] = 1.25;
				g_esGeneral.g_flDamageResistanceReward[iPos] = 0.5;
				g_esGeneral.g_iFriendlyFireReward[iPos] = 1;
				g_esGeneral.g_flHealPercentReward[iPos] = 100.0;
				g_esGeneral.g_iHealthRegenReward[iPos] = 1;
				g_esGeneral.g_iHollowpointAmmoReward[iPos] = 1;
				g_esGeneral.g_flJumpHeightReward[iPos] = 75.0;
				g_esGeneral.g_iInextinguishableFireReward[iPos] = 1;
				g_esGeneral.g_iInfiniteAmmoReward[iPos] = 31;
				g_esGeneral.g_iLadderActionsReward[iPos] = 1;
				g_esGeneral.g_iLadyKillerReward[iPos] = 1;
				g_esGeneral.g_iLifeLeechReward[iPos] = 1;
				g_esGeneral.g_flLoopingVoicelineInterval[iPos] = 10.0;
				g_esGeneral.g_iMeleeRangeReward[iPos] = 150;
				g_esGeneral.g_iMidairDashesReward[iPos] = 2;
				g_esGeneral.g_iParticleEffectVisual[iPos] = 15;
				g_esGeneral.g_flPipeBombDurationReward[iPos] = 10.0;
				g_esGeneral.g_iPrefsNotify[iPos] = 1;
				g_esGeneral.g_flPunchResistanceReward[iPos] = 0.25;
				g_esGeneral.g_iRecoilDampenerReward[iPos] = 1;
				g_esGeneral.g_iRespawnLoadoutReward[iPos] = 1;
				g_esGeneral.g_iReviveHealthReward[iPos] = 100;
				g_esGeneral.g_iShareRewards[iPos] = 0;
				g_esGeneral.g_flShoveDamageReward[iPos] = 0.025;
				g_esGeneral.g_iShovePenaltyReward[iPos] = 1;
				g_esGeneral.g_flShoveRateReward[iPos] = 0.7;
				g_esGeneral.g_iSledgehammerRoundsReward[iPos] = 1;
				g_esGeneral.g_iSpecialAmmoReward[iPos] = 3;
				g_esGeneral.g_flSpeedBoostReward[iPos] = 1.25;
				g_esGeneral.g_iStackRewards[iPos] = 0;
				g_esGeneral.g_iThornsReward[iPos] = 1;
				g_esGeneral.g_iUsefulRewards[iPos] = 15;
				g_esGeneral.g_iVoicePitchVisual[iPos] = 100;
			}

			if (iPos < (sizeof esGeneral::g_iStackLimits))
			{
				g_esGeneral.g_iStackLimits[iPos] = 0;
			}

			if (iPos < (sizeof esGeneral::g_flDifficultyDamage))
			{
				g_esGeneral.g_flDifficultyDamage[iPos] = 0.0;
			}
		}

		for (int iIndex = 0; iIndex <= MT_MAXTYPES; iIndex++)
		{
			g_esTank[iIndex].g_iAbilityCount = -1;
			g_esTank[iIndex].g_sGlowColor = "255,255,255";
			g_esTank[iIndex].g_sSkinColor = "255,255,255,255";
			g_esTank[iIndex].g_sFlameColor = "255,255,255,255";
			g_esTank[iIndex].g_sFlashlightColor = "255,255,255,255";
			g_esTank[iIndex].g_sOzTankColor = "255,255,255,255";
			g_esTank[iIndex].g_sPropTankColor = "255,255,255,255";
			g_esTank[iIndex].g_sRockColor = "255,255,255,255";
			g_esTank[iIndex].g_sTireColor = "255,255,255,255";
			g_esTank[iIndex].g_sTankName = "Tank";
			g_esTank[iIndex].g_iGameType = 0;
			g_esTank[iIndex].g_iTankEnabled = -1;
			g_esTank[iIndex].g_flTankChance = 100.0;
			g_esTank[iIndex].g_iTankNote = 0;
			g_esTank[iIndex].g_iTankModel = 0;
			g_esTank[iIndex].g_flBurnDuration = 0.0;
			g_esTank[iIndex].g_flBurntSkin = -1.0;
			g_esTank[iIndex].g_iSpawnEnabled = 1;
			g_esTank[iIndex].g_iMenuEnabled = 1;
			g_esTank[iIndex].g_iCheckAbilities = 0;
			g_esTank[iIndex].g_iDeathRevert = 0;
			g_esTank[iIndex].g_iAnnounceArrival = 0;
			g_esTank[iIndex].g_iAnnounceDeath = 0;
			g_esTank[iIndex].g_iAnnounceKill = 0;
			g_esTank[iIndex].g_iArrivalMessage = 0;
			g_esTank[iIndex].g_iArrivalSound = 0;
			g_esTank[iIndex].g_iDeathDetails = 0;
			g_esTank[iIndex].g_iDeathMessage = 0;
			g_esTank[iIndex].g_iDeathSound = 0;
			g_esTank[iIndex].g_iKillMessage = 0;
			g_esTank[iIndex].g_iVocalizeArrival = 0;
			g_esTank[iIndex].g_iVocalizeDeath = 0;
			g_esTank[iIndex].g_sBodyColorVisual[0] = '\0';
			g_esTank[iIndex].g_sBodyColorVisual2[0] = '\0';
			g_esTank[iIndex].g_sBodyColorVisual3[0] = '\0';
			g_esTank[iIndex].g_sBodyColorVisual4[0] = '\0';
			g_esTank[iIndex].g_sFallVoicelineReward[0] = '\0';
			g_esTank[iIndex].g_sFallVoicelineReward2[0] = '\0';
			g_esTank[iIndex].g_sFallVoicelineReward3[0] = '\0';
			g_esTank[iIndex].g_sFallVoicelineReward4[0] = '\0';
			g_esTank[iIndex].g_sItemReward[0] = '\0';
			g_esTank[iIndex].g_sItemReward2[0] = '\0';
			g_esTank[iIndex].g_sItemReward3[0] = '\0';
			g_esTank[iIndex].g_sItemReward4[0] = '\0';
			g_esTank[iIndex].g_sLightColorVisual[0] = '\0';
			g_esTank[iIndex].g_sLightColorVisual2[0] = '\0';
			g_esTank[iIndex].g_sLightColorVisual3[0] = '\0';
			g_esTank[iIndex].g_sLightColorVisual4[0] = '\0';
			g_esTank[iIndex].g_sLoopingVoicelineVisual[0] = '\0';
			g_esTank[iIndex].g_sLoopingVoicelineVisual2[0] = '\0';
			g_esTank[iIndex].g_sLoopingVoicelineVisual3[0] = '\0';
			g_esTank[iIndex].g_sLoopingVoicelineVisual4[0] = '\0';
			g_esTank[iIndex].g_sOutlineColorVisual[0] = '\0';
			g_esTank[iIndex].g_sOutlineColorVisual2[0] = '\0';
			g_esTank[iIndex].g_sOutlineColorVisual3[0] = '\0';
			g_esTank[iIndex].g_sOutlineColorVisual4[0] = '\0';
			g_esTank[iIndex].g_sScreenColorVisual[0] = '\0';
			g_esTank[iIndex].g_sScreenColorVisual2[0] = '\0';
			g_esTank[iIndex].g_sScreenColorVisual3[0] = '\0';
			g_esTank[iIndex].g_sScreenColorVisual4[0] = '\0';
			g_esTank[iIndex].g_iTeammateLimit = 0;
			g_esTank[iIndex].g_iAutoAggravate = 0;
			g_esTank[iIndex].g_iBaseHealth = 0;
			g_esTank[iIndex].g_iDisplayHealth = 0;
			g_esTank[iIndex].g_iDisplayHealthType = 0;
			g_esTank[iIndex].g_iExtraHealth = 0;
			g_esTank[iIndex].g_sHealthCharacters[0] = '\0';
			g_esTank[iIndex].g_flHealPercentMultiplier = 0.0;
			g_esTank[iIndex].g_iHumanMultiplierMode = 0;
			g_esTank[iIndex].g_iMinimumHumans = 0;
			g_esTank[iIndex].g_iMultiplyHealth = 0;
			g_esTank[iIndex].g_iHumanSupport = 0;
			g_esTank[iIndex].g_iRequiresHumans = 0;
			g_esTank[iIndex].g_iGlowEnabled = 0;
			g_esTank[iIndex].g_iGlowFlashing = 0;
			g_esTank[iIndex].g_iGlowMinRange = 0;
			g_esTank[iIndex].g_iGlowMaxRange = 99999;
			g_esTank[iIndex].g_iGlowType = 0;
			g_esTank[iIndex].g_flCloseAreasOnly = 0.0;
			g_esTank[iIndex].g_flOpenAreasOnly = 0.0;
			g_esTank[iIndex].g_iAccessFlags = 0;
			g_esTank[iIndex].g_iImmunityFlags = 0;
			g_esTank[iIndex].g_iTypeLimit = 0;
			g_esTank[iIndex].g_iFinaleTank = 0;
			g_esTank[iIndex].g_iBossBaseType = 0;
			g_esTank[iIndex].g_iBossLimit = 32;
			g_esTank[iIndex].g_iBossStages = 4;
			g_esTank[iIndex].g_sComboSet[0] = '\0';
			g_esTank[iIndex].g_iRandomTank = 1;
			g_esTank[iIndex].g_flRandomDuration = 99999.0;
			g_esTank[iIndex].g_flRandomInterval = 5.0;
			g_esTank[iIndex].g_flTransformDelay = 10.0;
			g_esTank[iIndex].g_flTransformDuration = 10.0;
			g_esTank[iIndex].g_iSpawnType = 0;
			g_esTank[iIndex].g_iPropsAttached = g_bSecondGame ? 510 : 462;
			g_esTank[iIndex].g_iBodyEffects = 0;
			g_esTank[iIndex].g_iRockEffects = 0;
			g_esTank[iIndex].g_iRockModel = 2;
			g_esTank[iIndex].g_flAttackInterval = 0.0;
			g_esTank[iIndex].g_flClawDamage = -1.0;
			g_esTank[iIndex].g_iGroundPound = 0;
			g_esTank[iIndex].g_flHittableDamage = -1.0;
			g_esTank[iIndex].g_flIncapDamageMultiplier = 0.0;
			g_esTank[iIndex].g_flPunchForce = -1.0;
			g_esTank[iIndex].g_flPunchThrow = 0.0;
			g_esTank[iIndex].g_flRockDamage = -1.0;
			g_esTank[iIndex].g_iRockSound = 0;
			g_esTank[iIndex].g_flRunSpeed = 0.0;
			g_esTank[iIndex].g_iSkipIncap = 0;
			g_esTank[iIndex].g_iSkipTaunt = 0;
			g_esTank[iIndex].g_iSweepFist = 0;
			g_esTank[iIndex].g_flThrowInterval = 0.0;
			g_esTank[iIndex].g_iBulletImmunity = 0;
			g_esTank[iIndex].g_iExplosiveImmunity = 0;
			g_esTank[iIndex].g_iFireImmunity = 0;
			g_esTank[iIndex].g_iHittableImmunity = 0;
			g_esTank[iIndex].g_iMeleeImmunity = 0;
			g_esTank[iIndex].g_iVomitImmunity = 0;

			for (int iPos = 0; iPos < (sizeof esTank::g_iTransformType); iPos++)
			{
				g_esTank[iIndex].g_iTransformType[iPos] = (iPos + 1);

				if (iPos < (sizeof esTank::g_iRewardEnabled))
				{
					g_esTank[iIndex].g_iRewardEnabled[iPos] = -1;
					g_esTank[iIndex].g_iRewardBots[iPos] = -1;
					g_esTank[iIndex].g_flRewardChance[iPos] = 0.0;
					g_esTank[iIndex].g_flRewardDuration[iPos] = 0.0;
					g_esTank[iIndex].g_iRewardEffect[iPos] = 0;
					g_esTank[iIndex].g_iRewardNotify[iPos] = 0;
					g_esTank[iIndex].g_flRewardPercentage[iPos] = 0.0;
					g_esTank[iIndex].g_iRewardVisual[iPos] = 0;
					g_esTank[iIndex].g_flActionDurationReward[iPos] = 0.0;
					g_esTank[iIndex].g_iAmmoBoostReward[iPos] = 0;
					g_esTank[iIndex].g_iAmmoRegenReward[iPos] = 0;
					g_esTank[iIndex].g_flAttackBoostReward[iPos] = 0.0;
					g_esTank[iIndex].g_iBunnyHopReward[iPos] = 0;
					g_esTank[iIndex].g_iBurstDoorsReward[iPos] = 0;
					g_esTank[iIndex].g_iCleanKillsReward[iPos] = 0;
					g_esTank[iIndex].g_flDamageBoostReward[iPos] = 0.0;
					g_esTank[iIndex].g_flDamageResistanceReward[iPos] = 0.0;
					g_esTank[iIndex].g_iFriendlyFireReward[iPos] = 0;
					g_esTank[iIndex].g_flHealPercentReward[iPos] = 0.0;
					g_esTank[iIndex].g_iHealthRegenReward[iPos] = 0;
					g_esTank[iIndex].g_iHollowpointAmmoReward[iPos] = 0;
					g_esTank[iIndex].g_flJumpHeightReward[iPos] = 0.0;
					g_esTank[iIndex].g_iInextinguishableFireReward[iPos] = 0;
					g_esTank[iIndex].g_iInfiniteAmmoReward[iPos] = 0;
					g_esTank[iIndex].g_iLadderActionsReward[iPos] = 0;
					g_esTank[iIndex].g_iLadyKillerReward[iPos] = 0;
					g_esTank[iIndex].g_iLifeLeechReward[iPos] = 0;
					g_esTank[iIndex].g_flLoopingVoicelineInterval[iPos] = 0.0;
					g_esTank[iIndex].g_iMeleeRangeReward[iPos] = 0;
					g_esTank[iIndex].g_iMidairDashesReward[iPos] = 0;
					g_esTank[iIndex].g_iParticleEffectVisual[iPos] = 0;
					g_esTank[iIndex].g_flPipeBombDurationReward[iPos] = 0.0;
					g_esTank[iIndex].g_iPrefsNotify[iPos] = 0;
					g_esTank[iIndex].g_flPunchResistanceReward[iPos] = 0.0;
					g_esTank[iIndex].g_iRecoilDampenerReward[iPos] = 0;
					g_esTank[iIndex].g_iRespawnLoadoutReward[iPos] = 0;
					g_esTank[iIndex].g_iReviveHealthReward[iPos] = 0;
					g_esTank[iIndex].g_iShareRewards[iPos] = 0;
					g_esTank[iIndex].g_flShoveDamageReward[iPos] = 0.0;
					g_esTank[iIndex].g_iShovePenaltyReward[iPos] = 0;
					g_esTank[iIndex].g_flShoveRateReward[iPos] = 0.0;
					g_esTank[iIndex].g_iSledgehammerRoundsReward[iPos] = 0;
					g_esTank[iIndex].g_iSpecialAmmoReward[iPos] = 0;
					g_esTank[iIndex].g_flSpeedBoostReward[iPos] = 0.0;
					g_esTank[iIndex].g_iStackRewards[iPos] = 0;
					g_esTank[iIndex].g_iThornsReward[iPos] = 0;
					g_esTank[iIndex].g_iUsefulRewards[iPos] = 0;
					g_esTank[iIndex].g_iVoicePitchVisual[iPos] = 0;
				}

				if (iPos < (sizeof esTank::g_iStackLimits))
				{
					g_esTank[iIndex].g_iStackLimits[iPos] = 0;
				}

				if (iPos < (sizeof esTank::g_flComboChance))
				{
					g_esTank[iIndex].g_flComboChance[iPos] = 0.0;
					g_esTank[iIndex].g_iComboCooldown[iPos] = 0;
					g_esTank[iIndex].g_flComboDamage[iPos] = 0.0;
					g_esTank[iIndex].g_flComboDeathChance[iPos] = 0.0;
					g_esTank[iIndex].g_flComboDeathRange[iPos] = 0.0;
					g_esTank[iIndex].g_flComboDelay[iPos] = 0.0;
					g_esTank[iIndex].g_flComboDuration[iPos] = 0.0;
					g_esTank[iIndex].g_flComboInterval[iPos] = 0.0;
					g_esTank[iIndex].g_flComboMaxRadius[iPos] = 0.0;
					g_esTank[iIndex].g_flComboMinRadius[iPos] = 0.0;
					g_esTank[iIndex].g_flComboRange[iPos] = 0.0;
					g_esTank[iIndex].g_flComboRangeChance[iPos] = 0.0;
					g_esTank[iIndex].g_iComboRangeCooldown[iPos] = 0;
					g_esTank[iIndex].g_flComboRockChance[iPos] = 0.0;
					g_esTank[iIndex].g_iComboRockCooldown[iPos] = 0;
					g_esTank[iIndex].g_flComboSpeed[iPos] = 0.0;
				}

				if (iPos < (sizeof esTank::g_flComboTypeChance))
				{
					g_esTank[iIndex].g_flComboTypeChance[iPos] = 0.0;
				}

				if (iPos < (sizeof esTank::g_flPropsChance))
				{
					g_esTank[iIndex].g_flPropsChance[iPos] = 33.3;
				}

				if (iPos < (sizeof esTank::g_iSkinColor))
				{
					g_esTank[iIndex].g_iSkinColor[iPos] = 255;
					g_esTank[iIndex].g_iBossHealth[iPos] = 5000 / (iPos + 1);
					g_esTank[iIndex].g_iBossType[iPos] = (iPos + 2);
					g_esTank[iIndex].g_iLightColor[iPos] = 255;
					g_esTank[iIndex].g_iOzTankColor[iPos] = 255;
					g_esTank[iIndex].g_iFlameColor[iPos] = 255;
					g_esTank[iIndex].g_iRockColor[iPos] = 255;
					g_esTank[iIndex].g_iTireColor[iPos] = 255;
					g_esTank[iIndex].g_iPropTankColor[iPos] = 255;
					g_esTank[iIndex].g_iFlashlightColor[iPos] = 255;
					g_esTank[iIndex].g_iCrownColor[iPos] = 255;
				}

				if (iPos < (sizeof esTank::g_iGlowColor))
				{
					g_esTank[iIndex].g_iGlowColor[iPos] = 255;
				}
			}
		}
	}

	if (g_esGeneral.g_iConfigMode == 3)
	{
		for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
		{
			if (bIsValidClient(iPlayer, MT_CHECK_INGAME|MT_CHECK_FAKECLIENT))
			{
				g_esPlayer[iPlayer].g_sGlowColor[0] = '\0';
				g_esPlayer[iPlayer].g_sSkinColor[0] = '\0';
				g_esPlayer[iPlayer].g_sFlameColor[0] = '\0';
				g_esPlayer[iPlayer].g_sFlashlightColor[0] = '\0';
				g_esPlayer[iPlayer].g_sOzTankColor[0] = '\0';
				g_esPlayer[iPlayer].g_sPropTankColor[0] = '\0';
				g_esPlayer[iPlayer].g_sRockColor[0] = '\0';
				g_esPlayer[iPlayer].g_sTireColor[0] = '\0';
				g_esPlayer[iPlayer].g_sTankName[0] = '\0';
				g_esPlayer[iPlayer].g_iTankModel = 0;
				g_esPlayer[iPlayer].g_flBurnDuration = 0.0;
				g_esPlayer[iPlayer].g_flBurntSkin = -1.0;
				g_esPlayer[iPlayer].g_iTankNote = 0;
				g_esPlayer[iPlayer].g_iCheckAbilities = 0;
				g_esPlayer[iPlayer].g_iDeathRevert = 0;
				g_esPlayer[iPlayer].g_iAnnounceArrival = 0;
				g_esPlayer[iPlayer].g_iAnnounceDeath = 0;
				g_esPlayer[iPlayer].g_iAnnounceKill = 0;
				g_esPlayer[iPlayer].g_iArrivalMessage = 0;
				g_esPlayer[iPlayer].g_iArrivalSound = 0;
				g_esPlayer[iPlayer].g_iDeathDetails = 0;
				g_esPlayer[iPlayer].g_iDeathMessage = 0;
				g_esPlayer[iPlayer].g_iDeathSound = 0;
				g_esPlayer[iPlayer].g_iKillMessage = 0;
				g_esPlayer[iPlayer].g_iVocalizeArrival = 0;
				g_esPlayer[iPlayer].g_iVocalizeDeath = 0;
				g_esPlayer[iPlayer].g_sBodyColorVisual[0] = '\0';
				g_esPlayer[iPlayer].g_sBodyColorVisual2[0] = '\0';
				g_esPlayer[iPlayer].g_sBodyColorVisual3[0] = '\0';
				g_esPlayer[iPlayer].g_sBodyColorVisual4[0] = '\0';
				g_esPlayer[iPlayer].g_sFallVoicelineReward[0] = '\0';
				g_esPlayer[iPlayer].g_sFallVoicelineReward2[0] = '\0';
				g_esPlayer[iPlayer].g_sFallVoicelineReward3[0] = '\0';
				g_esPlayer[iPlayer].g_sFallVoicelineReward4[0] = '\0';
				g_esPlayer[iPlayer].g_sItemReward[0] = '\0';
				g_esPlayer[iPlayer].g_sItemReward2[0] = '\0';
				g_esPlayer[iPlayer].g_sItemReward3[0] = '\0';
				g_esPlayer[iPlayer].g_sItemReward4[0] = '\0';
				g_esPlayer[iPlayer].g_sLightColorVisual[0] = '\0';
				g_esPlayer[iPlayer].g_sLightColorVisual2[0] = '\0';
				g_esPlayer[iPlayer].g_sLightColorVisual3[0] = '\0';
				g_esPlayer[iPlayer].g_sLightColorVisual4[0] = '\0';
				g_esPlayer[iPlayer].g_sLoopingVoicelineVisual[0] = '\0';
				g_esPlayer[iPlayer].g_sLoopingVoicelineVisual2[0] = '\0';
				g_esPlayer[iPlayer].g_sLoopingVoicelineVisual3[0] = '\0';
				g_esPlayer[iPlayer].g_sLoopingVoicelineVisual4[0] = '\0';
				g_esPlayer[iPlayer].g_sOutlineColorVisual[0] = '\0';
				g_esPlayer[iPlayer].g_sOutlineColorVisual2[0] = '\0';
				g_esPlayer[iPlayer].g_sOutlineColorVisual3[0] = '\0';
				g_esPlayer[iPlayer].g_sOutlineColorVisual4[0] = '\0';
				g_esPlayer[iPlayer].g_sScreenColorVisual[0] = '\0';
				g_esPlayer[iPlayer].g_sScreenColorVisual2[0] = '\0';
				g_esPlayer[iPlayer].g_sScreenColorVisual3[0] = '\0';
				g_esPlayer[iPlayer].g_sScreenColorVisual4[0] = '\0';
				g_esPlayer[iPlayer].g_iTeammateLimit = 0;
				g_esPlayer[iPlayer].g_iBaseHealth = 0;
				g_esPlayer[iPlayer].g_iDisplayHealth = 0;
				g_esPlayer[iPlayer].g_iDisplayHealthType = 0;
				g_esPlayer[iPlayer].g_iExtraHealth = 0;
				g_esPlayer[iPlayer].g_sHealthCharacters[0] = '\0';
				g_esPlayer[iPlayer].g_flHealPercentMultiplier = 0.0;
				g_esPlayer[iPlayer].g_iHumanMultiplierMode = 0;
				g_esPlayer[iPlayer].g_iMinimumHumans = 0;
				g_esPlayer[iPlayer].g_iMultiplyHealth = 0;
				g_esPlayer[iPlayer].g_iGlowEnabled = 0;
				g_esPlayer[iPlayer].g_iGlowFlashing = 0;
				g_esPlayer[iPlayer].g_iGlowMinRange = 0;
				g_esPlayer[iPlayer].g_iGlowMaxRange = 0;
				g_esPlayer[iPlayer].g_iGlowType = 0;
				g_esPlayer[iPlayer].g_iFavoriteType = 0;
				g_esPlayer[iPlayer].g_iAccessFlags = 0;
				g_esPlayer[iPlayer].g_iImmunityFlags = 0;
				g_esPlayer[iPlayer].g_iBossStages = 0;
				g_esPlayer[iPlayer].g_sComboSet[0] = '\0';
				g_esPlayer[iPlayer].g_iRandomTank = 0;
				g_esPlayer[iPlayer].g_flRandomDuration = 0.0;
				g_esPlayer[iPlayer].g_flRandomInterval = 0.0;
				g_esPlayer[iPlayer].g_flTransformDelay = 0.0;
				g_esPlayer[iPlayer].g_flTransformDuration = 0.0;
				g_esPlayer[iPlayer].g_iSpawnType = 0;
				g_esPlayer[iPlayer].g_iPropsAttached = 0;
				g_esPlayer[iPlayer].g_iBodyEffects = 0;
				g_esPlayer[iPlayer].g_iRockEffects = 0;
				g_esPlayer[iPlayer].g_iRockModel = 0;
				g_esPlayer[iPlayer].g_flAttackInterval = 0.0;
				g_esPlayer[iPlayer].g_flClawDamage = -1.0;
				g_esPlayer[iPlayer].g_iGroundPound = 0;
				g_esPlayer[iPlayer].g_flHittableDamage = -1.0;
				g_esPlayer[iPlayer].g_flIncapDamageMultiplier = 0.0;
				g_esPlayer[iPlayer].g_flPunchForce = -1.0;
				g_esPlayer[iPlayer].g_flPunchThrow = 0.0;
				g_esPlayer[iPlayer].g_flRockDamage = -1.0;
				g_esPlayer[iPlayer].g_iRockSound = 0;
				g_esPlayer[iPlayer].g_flRunSpeed = 0.0;
				g_esPlayer[iPlayer].g_iSkipIncap = 0;
				g_esPlayer[iPlayer].g_iSkipTaunt = 0;
				g_esPlayer[iPlayer].g_iSweepFist = 0;
				g_esPlayer[iPlayer].g_flThrowInterval = 0.0;
				g_esPlayer[iPlayer].g_iBulletImmunity = 0;
				g_esPlayer[iPlayer].g_iExplosiveImmunity = 0;
				g_esPlayer[iPlayer].g_iFireImmunity = 0;
				g_esPlayer[iPlayer].g_iHittableImmunity = 0;
				g_esPlayer[iPlayer].g_iMeleeImmunity = 0;
				g_esPlayer[iPlayer].g_iVomitImmunity = 0;

				for (int iPos = 0; iPos < (sizeof esPlayer::g_iTransformType); iPos++)
				{
					g_esPlayer[iPlayer].g_iTransformType[iPos] = 0;

					if (iPos < (sizeof esPlayer::g_iRewardEnabled))
					{
						g_esPlayer[iPlayer].g_iRewardEnabled[iPos] = -1;
						g_esPlayer[iPlayer].g_iRewardBots[iPos] = -1;
						g_esPlayer[iPlayer].g_flRewardChance[iPos] = 0.0;
						g_esPlayer[iPlayer].g_flRewardDuration[iPos] = 0.0;
						g_esPlayer[iPlayer].g_iRewardEffect[iPos] = 0;
						g_esPlayer[iPlayer].g_iRewardNotify[iPos] = 0;
						g_esPlayer[iPlayer].g_flRewardPercentage[iPos] = 0.0;
						g_esPlayer[iPlayer].g_iRewardVisual[iPos] = 0;
						g_esPlayer[iPlayer].g_flActionDurationReward[iPos] = 0.0;
						g_esPlayer[iPlayer].g_iAmmoBoostReward[iPos] = 0;
						g_esPlayer[iPlayer].g_iAmmoRegenReward[iPos] = 0;
						g_esPlayer[iPlayer].g_flAttackBoostReward[iPos] = 0.0;
						g_esPlayer[iPlayer].g_iBunnyHopReward[iPos] = 0;
						g_esPlayer[iPlayer].g_iBurstDoorsReward[iPos] = 0;
						g_esPlayer[iPlayer].g_iCleanKillsReward[iPos] = 0;
						g_esPlayer[iPlayer].g_flDamageBoostReward[iPos] = 0.0;
						g_esPlayer[iPlayer].g_flDamageResistanceReward[iPos] = 0.0;
						g_esPlayer[iPlayer].g_iFriendlyFireReward[iPos] = 0;
						g_esPlayer[iPlayer].g_flHealPercentReward[iPos] = 0.0;
						g_esPlayer[iPlayer].g_iHealthRegenReward[iPos] = 0;
						g_esPlayer[iPlayer].g_iHollowpointAmmoReward[iPos] = 0;
						g_esPlayer[iPlayer].g_flJumpHeightReward[iPos] = 0.0;
						g_esPlayer[iPlayer].g_iInextinguishableFireReward[iPos] = 0;
						g_esPlayer[iPlayer].g_iInfiniteAmmoReward[iPos] = 0;
						g_esPlayer[iPlayer].g_iLadderActionsReward[iPos] = 0;
						g_esPlayer[iPlayer].g_iLadyKillerReward[iPos] = 0;
						g_esPlayer[iPlayer].g_iLifeLeechReward[iPos] = 0;
						g_esPlayer[iPlayer].g_flLoopingVoicelineInterval[iPos] = 0.0;
						g_esPlayer[iPlayer].g_iMeleeRangeReward[iPos] = 0;
						g_esPlayer[iPlayer].g_iMidairDashesReward[iPos] = 0;
						g_esPlayer[iPlayer].g_iParticleEffectVisual[iPos] = 0;
						g_esPlayer[iPlayer].g_flPipeBombDurationReward[iPos] = 0.0;
						g_esPlayer[iPlayer].g_iPrefsNotify[iPos] = 0;
						g_esPlayer[iPlayer].g_flPunchResistanceReward[iPos] = 0.0;
						g_esPlayer[iPlayer].g_iRecoilDampenerReward[iPos] = 0;
						g_esPlayer[iPlayer].g_iRespawnLoadoutReward[iPos] = 0;
						g_esPlayer[iPlayer].g_iReviveHealthReward[iPos] = 0;
						g_esPlayer[iPlayer].g_iShareRewards[iPos] = 0;
						g_esPlayer[iPlayer].g_flShoveDamageReward[iPos] = 0.0;
						g_esPlayer[iPlayer].g_iShovePenaltyReward[iPos] = 0;
						g_esPlayer[iPlayer].g_flShoveRateReward[iPos] = 0.0;
						g_esPlayer[iPlayer].g_iSledgehammerRoundsReward[iPos] = 0;
						g_esPlayer[iPlayer].g_iSpecialAmmoReward[iPos] = 0;
						g_esPlayer[iPlayer].g_flSpeedBoostReward[iPos] = 0.0;
						g_esPlayer[iPlayer].g_iStackRewards[iPos] = 0;
						g_esPlayer[iPlayer].g_iThornsReward[iPos] = 0;
						g_esPlayer[iPlayer].g_iUsefulRewards[iPos] = 0;
						g_esPlayer[iPlayer].g_iVoicePitchVisual[iPos] = 0;
					}

					if (iPos < (sizeof esPlayer::g_iStackLimits))
					{
						g_esPlayer[iPlayer].g_iStackLimits[iPos] = 0;
					}

					if (iPos < (sizeof esPlayer::g_flComboChance))
					{
						g_esPlayer[iPlayer].g_flComboChance[iPos] = 0.0;
						g_esPlayer[iPlayer].g_iComboCooldown[iPos] = 0;
						g_esPlayer[iPlayer].g_flComboDamage[iPos] = 0.0;
						g_esPlayer[iPlayer].g_flComboDeathChance[iPos] = 0.0;
						g_esPlayer[iPlayer].g_flComboDeathRange[iPos] = 0.0;
						g_esPlayer[iPlayer].g_flComboDelay[iPos] = 0.0;
						g_esPlayer[iPlayer].g_flComboDuration[iPos] = 0.0;
						g_esPlayer[iPlayer].g_flComboInterval[iPos] = 0.0;
						g_esPlayer[iPlayer].g_flComboMaxRadius[iPos] = 0.0;
						g_esPlayer[iPlayer].g_flComboMinRadius[iPos] = 0.0;
						g_esPlayer[iPlayer].g_flComboRange[iPos] = 0.0;
						g_esPlayer[iPlayer].g_flComboRangeChance[iPos] = 0.0;
						g_esPlayer[iPlayer].g_iComboRangeCooldown[iPos] = 0;
						g_esPlayer[iPlayer].g_flComboRockChance[iPos] = 0.0;
						g_esPlayer[iPlayer].g_iComboRockCooldown[iPos] = 0;
						g_esPlayer[iPlayer].g_flComboSpeed[iPos] = 0.0;
					}

					if (iPos < (sizeof esPlayer::g_flComboTypeChance))
					{
						g_esPlayer[iPlayer].g_flComboTypeChance[iPos] = 0.0;
					}

					if (iPos < (sizeof esPlayer::g_flPropsChance))
					{
						g_esPlayer[iPlayer].g_flPropsChance[iPos] = 0.0;
					}

					if (iPos < (sizeof esPlayer::g_iSkinColor))
					{
						g_esPlayer[iPlayer].g_iSkinColor[iPos] = -1;
						g_esPlayer[iPlayer].g_iBossHealth[iPos] = 0;
						g_esPlayer[iPlayer].g_iBossType[iPos] = 0;
						g_esPlayer[iPlayer].g_iLightColor[iPos] = -1;
						g_esPlayer[iPlayer].g_iOzTankColor[iPos] = -1;
						g_esPlayer[iPlayer].g_iFlameColor[iPos] = -1;
						g_esPlayer[iPlayer].g_iRockColor[iPos] = -1;
						g_esPlayer[iPlayer].g_iTireColor[iPos] = -1;
						g_esPlayer[iPlayer].g_iPropTankColor[iPos] = -1;
						g_esPlayer[iPlayer].g_iFlashlightColor[iPos] = -1;
						g_esPlayer[iPlayer].g_iCrownColor[iPos] = -1;
					}

					if (iPos < (sizeof esPlayer::g_iGlowColor))
					{
						g_esPlayer[iPlayer].g_iGlowColor[iPos] = -1;
					}
				}

				for (int iIndex = 1; iIndex <= MT_MAXTYPES; iIndex++)
				{
					g_esAdmin[iIndex].g_iAccessFlags[iPlayer] = 0;
					g_esAdmin[iIndex].g_iImmunityFlags[iPlayer] = 0;
				}
			}
		}
	}

	Call_StartForward(g_esGeneral.g_gfConfigsLoadForward);
	Call_PushCell(g_esGeneral.g_iConfigMode);
	Call_Finish();
}

SMCResult SMCNewSection_Main(SMCParser smc, const char[] name, bool opt_quotes)
{
	if (g_esGeneral.g_iIgnoreLevel)
	{
		g_esGeneral.g_iIgnoreLevel++;

		return SMCParse_Continue;
	}

	if (g_esGeneral.g_csState == ConfigState_None)
	{
		switch (StrEqual(name, MT_CONFIG_SECTION_MAIN, false) || StrEqual(name, MT_CONFIG_SECTION_MAIN2, false) || StrEqual(name, MT_CONFIG_SECTION_MAIN3, false) || StrEqual(name, MT_CONFIG_SECTION_MAIN4, false) || StrEqual(name, MT_CONFIG_SECTION_MAIN5, false))
		{
			case true: g_esGeneral.g_csState = ConfigState_Start;
			case false: g_esGeneral.g_iIgnoreLevel++;
		}
	}
	else if (g_esGeneral.g_csState == ConfigState_Start)
	{
		if (StrEqual(name, MT_CONFIG_SECTION_SETTINGS, false) || StrEqual(name, MT_CONFIG_SECTION_SETTINGS2, false) || StrEqual(name, MT_CONFIG_SECTION_SETTINGS3, false) || StrEqual(name, MT_CONFIG_SECTION_SETTINGS4, false))
		{
			g_esGeneral.g_csState = ConfigState_Settings;

			strcopy(g_esGeneral.g_sCurrentSection, sizeof esGeneral::g_sCurrentSection, name);
		}
		else if (!strncmp(name, "Tank", 4, false) || name[0] == '#' || IsCharNumeric(name[0]) || StrContains(name, "all", false) != -1 || FindCharInString(name, ',') != -1 || FindCharInString(name, '-') != -1)
		{
			g_esGeneral.g_csState = ConfigState_Type;

			strcopy(g_esGeneral.g_sCurrentSection, sizeof esGeneral::g_sCurrentSection, name);

			if (!strncmp(name, "Tank", 4, false) || name[0] == '#')
			{
				int iStartPos = iGetConfigSectionNumber(g_esGeneral.g_sCurrentSection, sizeof esGeneral::g_sCurrentSection), iIndex = StringToInt(g_esGeneral.g_sCurrentSection[iStartPos]);
				for (int iType = 1; iType <= g_esGeneral.g_iTypeCounter[0]; iType++)
				{
					if (g_esTank[iType].g_iRealType[0] == iIndex)
					{
						vLogMessage(MT_LOG_SERVER, _, "%s A duplicate entry was found for \"%s\".", MT_TAG, g_esGeneral.g_sCurrentSection);
					}
				}

				if (iIndex > MT_MAXTYPES || g_esGeneral.g_iTypeCounter[0] > MT_MAXTYPES)
				{
					vLogMessage(MT_LOG_SERVER, _, "%s An entry (%s) was found that exceeds the limit (%i).", MT_TAG, g_esGeneral.g_sCurrentSection, MT_MAXTYPES);
				}

				g_esGeneral.g_iTypeCounter[0]++;

				if (g_esGeneral.g_iTypeCounter[0] <= MT_MAXTYPES)
				{
					g_esTank[g_esGeneral.g_iTypeCounter[0]].g_iRealType[0] = iIndex;
				}

				if (iIndex <= MT_MAXTYPES)
				{
					g_esTank[iIndex].g_iRecordedType[0] = g_esGeneral.g_iTypeCounter[0];
				}
			}
		}
		else if (!strncmp(name, "STEAM_", 6, false) || !strncmp("0:", name, 2) || !strncmp("1:", name, 2) || (!strncmp(name, "[U:", 3) && name[strlen(name) - 1] == ']'))
		{
			g_esGeneral.g_csState = ConfigState_Admin;

			strcopy(g_esGeneral.g_sCurrentSection, sizeof esGeneral::g_sCurrentSection, name);
		}
		else
		{
			g_esGeneral.g_iIgnoreLevel++;
		}
	}
	else if (g_esGeneral.g_csState == ConfigState_Settings || g_esGeneral.g_csState == ConfigState_Type || g_esGeneral.g_csState == ConfigState_Admin)
	{
		g_esGeneral.g_csState = ConfigState_Specific;

		strcopy(g_esGeneral.g_sCurrentSubSection, sizeof esGeneral::g_sCurrentSubSection, name);

		if (!strncmp(name, "Tank", 4, false) || name[0] == '#')
		{
			int iStartPos = iGetConfigSectionNumber(g_esGeneral.g_sCurrentSubSection, sizeof esGeneral::g_sCurrentSubSection), iIndex = StringToInt(g_esGeneral.g_sCurrentSubSection[iStartPos]);
			for (int iType = 1; iType <= g_esGeneral.g_iTypeCounter[1]; iType++)
			{
				if (g_esTank[iType].g_iRealType[1] == iIndex)
				{
					vLogMessage(MT_LOG_SERVER, _, "%s A duplicate entry was found for \"%s\".", MT_TAG, g_esGeneral.g_sCurrentSubSection);
				}
			}

			if (iIndex > MT_MAXTYPES || g_esGeneral.g_iTypeCounter[1] > MT_MAXTYPES)
			{
				vLogMessage(MT_LOG_SERVER, _, "%s An entry (%s) was found that exceeds the limit (%i).", MT_TAG, g_esGeneral.g_sCurrentSubSection, MT_MAXTYPES);
			}

			g_esGeneral.g_iTypeCounter[1]++;

			if (g_esGeneral.g_iTypeCounter[1] <= MT_MAXTYPES)
			{
				g_esTank[g_esGeneral.g_iTypeCounter[1]].g_iRealType[1] = iIndex;
			}

			if (iIndex <= MT_MAXTYPES)
			{
				g_esTank[iIndex].g_iRecordedType[1] = g_esGeneral.g_iTypeCounter[1];
			}
		}
	}
	else
	{
		g_esGeneral.g_iIgnoreLevel++;
	}

	return SMCParse_Continue;
}

SMCResult SMCKeyValues_Main(SMCParser smc, const char[] key, const char[] value, bool key_quotes, bool value_quotes)
{
	if (g_esGeneral.g_iIgnoreLevel)
	{
		return SMCParse_Continue;
	}

	if (g_esGeneral.g_csState == ConfigState_Specific && value[0] != '\0')
	{
		if (g_esGeneral.g_iConfigMode < 3)
		{
			if (StrEqual(g_esGeneral.g_sCurrentSection, MT_CONFIG_SECTION_SETTINGS, false) || StrEqual(g_esGeneral.g_sCurrentSection, MT_CONFIG_SECTION_SETTINGS2, false) || StrEqual(g_esGeneral.g_sCurrentSection, MT_CONFIG_SECTION_SETTINGS3, false) || StrEqual(g_esGeneral.g_sCurrentSection, MT_CONFIG_SECTION_SETTINGS4, false))
			{
				g_esGeneral.g_iPluginEnabled = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, key, "PluginEnabled", "Plugin Enabled", "Plugin_Enabled", "penabled", g_esGeneral.g_iPluginEnabled, value, 0, 1);
				g_esGeneral.g_iAutoUpdate = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, key, "AutoUpdate", "Auto Update", "Auto_Update", "update", g_esGeneral.g_iAutoUpdate, value, 0, 1);
				g_esGeneral.g_iListenSupport = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, key, "ListenSupport", "Listen Support", "Listen_Support", "listen", g_esGeneral.g_iListenSupport, value, 0, 1);
				g_esGeneral.g_iCheckAbilities = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, key, "CheckAbilities", "Check Abilities", "Check_Abilities", "check", g_esGeneral.g_iCheckAbilities, value, 0, 1);
				g_esGeneral.g_iDeathRevert = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, key, "DeathRevert", "Death Revert", "Death_Revert", "revert", g_esGeneral.g_iDeathRevert, value, 0, 1);
				g_esGeneral.g_iFinalesOnly = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, key, "FinalesOnly", "Finales Only", "Finales_Only", "finale", g_esGeneral.g_iFinalesOnly, value, 0, 4);
				g_esGeneral.g_flIdleCheck = flGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, key, "IdleCheck", "Idle Check", "Idle_Check", "idle", g_esGeneral.g_flIdleCheck, value, 0.0, 99999.0);
				g_esGeneral.g_iIdleCheckMode = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, key, "IdleCheckMode", "Idle Check Mode", "Idle_Check_Mode", "idlemode", g_esGeneral.g_iIdleCheckMode, value, 0, 2);
				g_esGeneral.g_iLogCommands = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, key, "LogCommands", "Log Commands", "Log_Commands", "logcmds", g_esGeneral.g_iLogCommands, value, 0, 31);
				g_esGeneral.g_iLogMessages = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, key, "LogMessages", "Log Messages", "Log_Messages", "logmsgs", g_esGeneral.g_iLogMessages, value, 0, 31);
				g_esGeneral.g_iRequiresHumans = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esGeneral.g_iRequiresHumans, value, 0, 32);
				g_esGeneral.g_iTankEnabled = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, key, "TankEnabled", "Tank Enabled", "Tank_Enabled", "tenabled", g_esGeneral.g_iTankEnabled, value, -1, 1);
				g_esGeneral.g_iTankModel = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, key, "TankModel", "Tank Model", "Tank_Model", "model", g_esGeneral.g_iTankModel, value, 0, 7);
				g_esGeneral.g_flBurnDuration = flGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, key, "BurnDuration", "Burn Duration", "Burn_Duration", "burndur", g_esGeneral.g_flBurnDuration, value, 0.0, 99999.0);
				g_esGeneral.g_flBurntSkin = flGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, key, "BurntSkin", "Burnt Skin", "Burnt_Skin", "burnt", g_esGeneral.g_flBurntSkin, value, -1.0, 1.0);
				g_esGeneral.g_iSpawnEnabled = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, key, "SpawnEnabled", "Spawn Enabled", "Spawn_Enabled", "spawn", g_esGeneral.g_iSpawnEnabled, value, -1, 1);
				g_esGeneral.g_iSpawnLimit = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, key, "SpawnLimit", "Spawn Limit", "Spawn_Limit", "limit", g_esGeneral.g_iSpawnLimit, value, 0, 32);
				g_esGeneral.g_iAnnounceArrival = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE2, key, "AnnounceArrival", "Announce Arrival", "Announce_Arrival", "arrival", g_esGeneral.g_iAnnounceArrival, value, 0, 31);
				g_esGeneral.g_iAnnounceDeath = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE2, key, "AnnounceDeath", "Announce Death", "Announce_Death", "death", g_esGeneral.g_iAnnounceDeath, value, 0, 2);
				g_esGeneral.g_iAnnounceKill = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE2, key, "AnnounceKill", "Announce Kill", "Announce_Kill", "kill", g_esGeneral.g_iAnnounceKill, value, 0, 1);
				g_esGeneral.g_iArrivalMessage = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE2, key, "ArrivalMessage", "Arrival Message", "Arrival_Message", "arrivalmsg", g_esGeneral.g_iArrivalMessage, value, 0, 1023);
				g_esGeneral.g_iArrivalSound = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE2, key, "ArrivalSound", "Arrival Sound", "Arrival_Sound", "arrivalsnd", g_esGeneral.g_iArrivalSound, value, 0, 1);
				g_esGeneral.g_iDeathDetails = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE2, key, "DeathDetails", "Death Details", "Death_Details", "deathdets", g_esGeneral.g_iDeathDetails, value, 0, 5);
				g_esGeneral.g_iDeathMessage = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE2, key, "DeathMessage", "Death Message", "Death_Message", "deathmsg", g_esGeneral.g_iDeathMessage, value, 0, 1023);
				g_esGeneral.g_iDeathSound = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE2, key, "DeathSound", "Death Sound", "Death_Sound", "deathsnd", g_esGeneral.g_iDeathSound, value, 0, 1);
				g_esGeneral.g_iKillMessage = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE2, key, "KillMessage", "Kill Message", "Kill_Message", "killmsg", g_esGeneral.g_iKillMessage, value, 0, 1023);
				g_esGeneral.g_iVocalizeArrival = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE2, key, "VocalizeArrival", "Vocalize Arrival", "Vocalize_Arrival", "arrivalvoc", g_esGeneral.g_iVocalizeArrival, value, 0, 1);
				g_esGeneral.g_iVocalizeDeath = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE2, key, "VocalizeDeath", "Vocalize Death", "Vocalize_Death", "deathvoc", g_esGeneral.g_iVocalizeDeath, value, 0, 1);
				g_esGeneral.g_iTeammateLimit = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_REWARDS, MT_CONFIG_SECTION_REWARDS, MT_CONFIG_SECTION_REWARDS, MT_CONFIG_SECTION_REWARDS, key, "TeammateLimit", "Teammate Limit", "Teammate_Limit", "teamlimit", g_esGeneral.g_iTeammateLimit, value, 0, 32);
				g_esGeneral.g_iAutoAggravate = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_COMP, MT_CONFIG_SECTION_COMP, MT_CONFIG_SECTION_COMP, MT_CONFIG_SECTION_COMP2, key, "AutoAggravate", "Auto Aggravate", "Auto_Aggravate", "autoaggro", g_esGeneral.g_iAutoAggravate, value, 0, 1);
				g_esGeneral.g_iCreditIgniters = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_COMP, MT_CONFIG_SECTION_COMP, MT_CONFIG_SECTION_COMP, MT_CONFIG_SECTION_COMP2, key, "CreditIgniters", "Credit Igniters", "Credit_Igniters", "credit", g_esGeneral.g_iCreditIgniters, value, 0, 1);
				g_esGeneral.g_flForceSpawn = flGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_COMP, MT_CONFIG_SECTION_COMP, MT_CONFIG_SECTION_COMP, MT_CONFIG_SECTION_COMP2, key, "ForceSpawn", "Force Spawn", "Force_Spawn", "force", g_esGeneral.g_flForceSpawn, value, 0.0, 99999.0);
				g_esGeneral.g_iStasisMode = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_COMP, MT_CONFIG_SECTION_COMP, MT_CONFIG_SECTION_COMP, MT_CONFIG_SECTION_COMP2, key, "StasisMode", "Stasis Mode", "Stasis_Mode", "stasis", g_esGeneral.g_iStasisMode, value, 0, 1);
				g_esGeneral.g_flSurvivalDelay = flGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_COMP, MT_CONFIG_SECTION_COMP, MT_CONFIG_SECTION_COMP, MT_CONFIG_SECTION_COMP2, key, "SurvivalDelay", "Survival Delay", "Survival_Delay", "survdelay", g_esGeneral.g_flSurvivalDelay, value, 0.1, 99999.0);
				g_esGeneral.g_iScaleDamage = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_DIFF, MT_CONFIG_SECTION_DIFF, MT_CONFIG_SECTION_DIFF, MT_CONFIG_SECTION_DIFF2, key, "ScaleDamage", "Scale Damage", "Scale_Damage", "scaledmg", g_esGeneral.g_iScaleDamage, value, 0, 1);
				g_esGeneral.g_iBaseHealth = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, key, "BaseHealth", "Base Health", "Base_Health", "basehp", g_esGeneral.g_iBaseHealth, value, 0, MT_MAXHEALTH);
				g_esGeneral.g_iDisplayHealth = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, key, "DisplayHealth", "Display Health", "Display_Health", "displayhp", g_esGeneral.g_iDisplayHealth, value, 0, 11);
				g_esGeneral.g_iDisplayHealthType = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, key, "DisplayHealthType", "Display Health Type", "Display_Health_Type", "displaytype", g_esGeneral.g_iDisplayHealthType, value, 0, 2);
				g_esGeneral.g_iExtraHealth = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, key, "ExtraHealth", "Extra Health", "Extra_Health", "extrahp", g_esGeneral.g_iExtraHealth, value, MT_MAX_HEALTH_REDUCTION, MT_MAXHEALTH);
				g_esGeneral.g_flHealPercentMultiplier = flGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, key, "HealthPercentageMultiplier", "Health Percentage Multiplier", "Health_Percentage_Multiplier", "hpmulti", g_esGeneral.g_flHealPercentMultiplier, value, 1.0, 99999.0);
				g_esGeneral.g_iHumanMultiplierMode = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, key, "HumanMultiplierMode", "Human Multiplier Mode", "Human_Multiplier_Mode", "humanmultimode", g_esGeneral.g_iHumanMultiplierMode, value, 0, 1);
				g_esGeneral.g_iMinimumHumans = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, key, "MinimumHumans", "Minimum Humans", "Minimum_Humans", "minhumans", g_esGeneral.g_iMinimumHumans, value, 1, 32);
				g_esGeneral.g_iMultiplyHealth = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, key, "MultiplyHealth", "Multiply Health", "Multiply_Health", "multihp", g_esGeneral.g_iMultiplyHealth, value, 0, 3);
				g_esGeneral.g_flAttackInterval = flGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE2, key, "AttackInterval", "Attack Interval", "Attack_Interval", "attack", g_esGeneral.g_flAttackInterval, value, 0.0, 99999.0);
				g_esGeneral.g_flClawDamage = flGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE2, key, "ClawDamage", "Claw Damage", "Claw_Damage", "claw", g_esGeneral.g_flClawDamage, value, -1.0, 99999.0);
				g_esGeneral.g_iGroundPound = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE2, key, "GroundPound", "Ground Pound", "Ground_Pound", "pound", g_esGeneral.g_iGroundPound, value, 0, 1);
				g_esGeneral.g_flHittableDamage = flGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE2, key, "HittableDamage", "Hittable Damage", "Hittable_Damage", "hittable", g_esGeneral.g_flHittableDamage, value, -1.0, 99999.0);
				g_esGeneral.g_flIncapDamageMultiplier = flGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE2, key, "IncapDamageMultiplier", "Incap Damage Multiplier", "Incap_Damage_Multiplier", "incapdmgmulti", g_esGeneral.g_flIncapDamageMultiplier, value, 1.0, 99999.0);
				g_esGeneral.g_flPunchForce = flGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE2, key, "PunchForce", "Punch Force", "Punch_Force", "punchf", g_esGeneral.g_flPunchForce, value, -1.0, 99999.0);
				g_esGeneral.g_flPunchThrow = flGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE2, key, "PunchThrow", "Punch Throw", "Punch_Throw", "puncht", g_esGeneral.g_flPunchThrow, value, 0.0, 100.0);
				g_esGeneral.g_flRockDamage = flGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE2, key, "RockDamage", "Rock Damage", "Rock_Damage", "rockdmg", g_esGeneral.g_flRockDamage, value, -1.0, 99999.0);
				g_esGeneral.g_iRockSound = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE2, key, "RockSound", "Rock Sound", "Rock_Sound", "rocksnd", g_esGeneral.g_iRockSound, value, 0, 1);
				g_esGeneral.g_flRunSpeed = flGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE2, key, "RunSpeed", "Run Speed", "Run_Speed", "speed", g_esGeneral.g_flRunSpeed, value, 0.0, 3.0);
				g_esGeneral.g_iSkipIncap = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE2, key, "SkipIncap", "Skip Incap", "Skip_Incap", "incap", g_esGeneral.g_iSkipIncap, value, 0, 1);
				g_esGeneral.g_iSkipTaunt = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE2, key, "SkipTaunt", "Skip Taunt", "Skip_Taunt", "taunt", g_esGeneral.g_iSkipTaunt, value, 0, 1);
				g_esGeneral.g_iSweepFist = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE2, key, "SweepFist", "Sweep Fist", "Sweep_Fist", "sweep", g_esGeneral.g_iSweepFist, value, 0, 1);
				g_esGeneral.g_flThrowInterval = flGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE2, key, "ThrowInterval", "Throw Interval", "Throw_Interval", "throw", g_esGeneral.g_flThrowInterval, value, 0.0, 99999.0);
				g_esGeneral.g_iBulletImmunity = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_IMMUNE, MT_CONFIG_SECTION_IMMUNE, MT_CONFIG_SECTION_IMMUNE, MT_CONFIG_SECTION_IMMUNE2, key, "BulletImmunity", "Bullet Immunity", "Bullet_Immunity", "bullet", g_esGeneral.g_iBulletImmunity, value, 0, 1);
				g_esGeneral.g_iExplosiveImmunity = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_IMMUNE, MT_CONFIG_SECTION_IMMUNE, MT_CONFIG_SECTION_IMMUNE, MT_CONFIG_SECTION_IMMUNE2, key, "ExplosiveImmunity", "Explosive Immunity", "Explosive_Immunity", "explosive", g_esGeneral.g_iExplosiveImmunity, value, 0, 1);
				g_esGeneral.g_iFireImmunity = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_IMMUNE, MT_CONFIG_SECTION_IMMUNE, MT_CONFIG_SECTION_IMMUNE, MT_CONFIG_SECTION_IMMUNE2, key, "FireImmunity", "Fire Immunity", "Fire_Immunity", "fire", g_esGeneral.g_iFireImmunity, value, 0, 1);
				g_esGeneral.g_iHittableImmunity = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_IMMUNE, MT_CONFIG_SECTION_IMMUNE, MT_CONFIG_SECTION_IMMUNE, MT_CONFIG_SECTION_IMMUNE2, key, "HittableImmunity", "Hittable Immunity", "Hittable_Immunity", "hittable", g_esGeneral.g_iHittableImmunity, value, 0, 1);
				g_esGeneral.g_iMeleeImmunity = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_IMMUNE, MT_CONFIG_SECTION_IMMUNE, MT_CONFIG_SECTION_IMMUNE, MT_CONFIG_SECTION_IMMUNE2, key, "MeleeImmunity", "Melee Immunity", "Melee_Immunity", "melee", g_esGeneral.g_iMeleeImmunity, value, 0, 1);
				g_esGeneral.g_iVomitImmunity = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_IMMUNE, MT_CONFIG_SECTION_IMMUNE, MT_CONFIG_SECTION_IMMUNE, MT_CONFIG_SECTION_IMMUNE2, key, "VomitImmunity", "Vomit Immunity", "Vomit_Immunity", "vomit", g_esGeneral.g_iVomitImmunity, value, 0, 1);
				g_esGeneral.g_iHumanCooldown = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_HUMAN, MT_CONFIG_SECTION_HUMAN2, MT_CONFIG_SECTION_HUMAN3, MT_CONFIG_SECTION_HUMAN4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "cooldown", g_esGeneral.g_iHumanCooldown, value, 0, 99999);
				g_esGeneral.g_iMasterControl = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_HUMAN, MT_CONFIG_SECTION_HUMAN2, MT_CONFIG_SECTION_HUMAN3, MT_CONFIG_SECTION_HUMAN4, key, "MasterControl", "Master Control", "Master_Control", "master", g_esGeneral.g_iMasterControl, value, 0, 1);
				g_esGeneral.g_iSpawnMode = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_HUMAN, MT_CONFIG_SECTION_HUMAN2, MT_CONFIG_SECTION_HUMAN3, MT_CONFIG_SECTION_HUMAN4, key, "SpawnMode", "Spawn Mode", "Spawn_Mode", "spawnmode", g_esGeneral.g_iSpawnMode, value, 0, 4);
				g_esGeneral.g_iLimitExtras = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_WAVES, MT_CONFIG_SECTION_WAVES, MT_CONFIG_SECTION_WAVES, MT_CONFIG_SECTION_WAVES, key, "LimitExtras", "Limit Extras", "Limit_Extras", "limitex", g_esGeneral.g_iLimitExtras, value, 0, 1);
				g_esGeneral.g_flExtrasDelay = flGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_WAVES, MT_CONFIG_SECTION_WAVES, MT_CONFIG_SECTION_WAVES, MT_CONFIG_SECTION_WAVES, key, "ExtrasDelay", "Extras Delay", "Extras_Delay", "exdelay", g_esGeneral.g_flExtrasDelay, value, 0.1, 99999.0);
				g_esGeneral.g_iRegularAmount = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_WAVES, MT_CONFIG_SECTION_WAVES, MT_CONFIG_SECTION_WAVES, MT_CONFIG_SECTION_WAVES, key, "RegularAmount", "Regular Amount", "Regular_Amount", "regamount", g_esGeneral.g_iRegularAmount, value, 0, 32);
				g_esGeneral.g_flRegularDelay = flGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_WAVES, MT_CONFIG_SECTION_WAVES, MT_CONFIG_SECTION_WAVES, MT_CONFIG_SECTION_WAVES, key, "RegularDelay", "Regular Delay", "Regular_Delay", "regdelay", g_esGeneral.g_flRegularDelay, value, 0.1, 99999.0);
				g_esGeneral.g_flRegularInterval = flGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_WAVES, MT_CONFIG_SECTION_WAVES, MT_CONFIG_SECTION_WAVES, MT_CONFIG_SECTION_WAVES, key, "RegularInterval", "Regular Interval", "Regular_Interval", "reginterval", g_esGeneral.g_flRegularInterval, value, 0.1, 99999.0);
				g_esGeneral.g_iRegularLimit = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_WAVES, MT_CONFIG_SECTION_WAVES, MT_CONFIG_SECTION_WAVES, MT_CONFIG_SECTION_WAVES, key, "RegularLimit", "Regular Limit", "Regular_Limit", "reglimit", g_esGeneral.g_iRegularLimit, value, 0, 99999);
				g_esGeneral.g_iRegularMode = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_WAVES, MT_CONFIG_SECTION_WAVES, MT_CONFIG_SECTION_WAVES, MT_CONFIG_SECTION_WAVES, key, "RegularMode", "Regular Mode", "Regular_Mode", "regmode", g_esGeneral.g_iRegularMode, value, 0, 1);
				g_esGeneral.g_iRegularWave = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_WAVES, MT_CONFIG_SECTION_WAVES, MT_CONFIG_SECTION_WAVES, MT_CONFIG_SECTION_WAVES, key, "RegularWave", "Regular Wave", "Regular_Wave", "regwave", g_esGeneral.g_iRegularWave, value, 0, 1);
				g_esGeneral.g_iFinaleAmount = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_WAVES, MT_CONFIG_SECTION_WAVES, MT_CONFIG_SECTION_WAVES, MT_CONFIG_SECTION_WAVES, key, "FinaleAmount", "Finale Amount", "Finale_Amount", "finamount", g_esGeneral.g_iFinaleAmount, value, 0, 32);
				g_esGeneral.g_iAccessFlags = iGetAdminFlagsValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_ADMIN, MT_CONFIG_SECTION_ADMIN, MT_CONFIG_SECTION_ADMIN, MT_CONFIG_SECTION_ADMIN2, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
				g_esGeneral.g_iImmunityFlags = iGetAdminFlagsValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_ADMIN, MT_CONFIG_SECTION_ADMIN, MT_CONFIG_SECTION_ADMIN, MT_CONFIG_SECTION_ADMIN2, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);

				vGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, key, "HealthCharacters", "Health Characters", "Health_Characters", "hpchars", g_esGeneral.g_sHealthCharacters, sizeof esGeneral::g_sHealthCharacters, value);

				if (StrEqual(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_GENERAL, false))
				{
					if (StrEqual(key, "TypeRange", false) || StrEqual(key, "Type Range", false) || StrEqual(key, "Type_Range", false) || StrEqual(key, "types", false))
					{
						char sValue[10], sRange[2][5];
						strcopy(sValue, sizeof sValue, value);
						ReplaceString(sValue, sizeof sValue, " ", "");
						ExplodeString(sValue, "-", sRange, sizeof sRange, sizeof sRange[]);

						g_esGeneral.g_iMinType = (sRange[0][0] != '\0') ? iClamp(StringToInt(sRange[0]), 0, MT_MAXTYPES) : g_esGeneral.g_iMinType;
						g_esGeneral.g_iMaxType = (sRange[1][0] != '\0') ? iClamp(StringToInt(sRange[1]), 0, MT_MAXTYPES) : g_esGeneral.g_iMaxType;
					}
				}
				else if (StrEqual(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_COLORS, false))
				{
					if (g_esGeneral.g_alColorKeys[0] != null)
					{
						g_esGeneral.g_alColorKeys[0].PushString(key);
					}

					if (g_esGeneral.g_alColorKeys[1] != null)
					{
						g_esGeneral.g_alColorKeys[1].PushString(value);
					}
				}
				else if (StrEqual(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_REWARDS, false))
				{
					char sValue[1280], sSet[7][320];
					strcopy(sValue, sizeof sValue, value);
					ReplaceString(sValue, sizeof sValue, " ", "");
					ExplodeString(sValue, ",", sSet, sizeof sSet, sizeof sSet[]);
					for (int iPos = 0; iPos < (sizeof esGeneral::g_iStackLimits); iPos++)
					{
						if (iPos < (sizeof esGeneral::g_iRewardEnabled))
						{
							g_esGeneral.g_flRewardChance[iPos] = flGetClampedValue(key, "RewardChance", "Reward Chance", "Reward_Chance", "chance", g_esGeneral.g_flRewardChance[iPos], sSet[iPos], 0.1, 100.0);
							g_esGeneral.g_flRewardDuration[iPos] = flGetClampedValue(key, "RewardDuration", "Reward Duration", "Reward_Duration", "duration", g_esGeneral.g_flRewardDuration[iPos], sSet[iPos], 0.1, 99999.0);
							g_esGeneral.g_flRewardPercentage[iPos] = flGetClampedValue(key, "RewardPercentage", "Reward Percentage", "Reward_Percentage", "percent", g_esGeneral.g_flRewardPercentage[iPos], sSet[iPos], 0.1, 100.0);
							g_esGeneral.g_flActionDurationReward[iPos] = flGetClampedValue(key, "ActionDurationReward", "Action Duration Reward", "Action_Duration_Reward", "actionduration", g_esGeneral.g_flActionDurationReward[iPos], sSet[iPos], 0.0, 99999.0);
							g_esGeneral.g_flAttackBoostReward[iPos] = flGetClampedValue(key, "AttackBoostReward", "Attack Boost Reward", "Attack_Boost_Reward", "attackboost", g_esGeneral.g_flAttackBoostReward[iPos], sSet[iPos], 0.0, 99999.0);
							g_esGeneral.g_flDamageBoostReward[iPos] = flGetClampedValue(key, "DamageBoostReward", "Damage Boost Reward", "Damage_Boost_Reward", "dmgboost", g_esGeneral.g_flDamageBoostReward[iPos], sSet[iPos], 0.0, 99999.0);
							g_esGeneral.g_flDamageResistanceReward[iPos] = flGetClampedValue(key, "DamageResistanceReward", "Damage Resistance Reward", "Damage_Resistance_Reward", "dmgres", g_esGeneral.g_flDamageResistanceReward[iPos], sSet[iPos], 0.0, 1.0);
							g_esGeneral.g_flHealPercentReward[iPos] = flGetClampedValue(key, "HealPercentReward", "Heal Percent Reward", "Heal_Percent_Reward", "healpercent", g_esGeneral.g_flHealPercentReward[iPos], sSet[iPos], 0.0, 100.0);
							g_esGeneral.g_flJumpHeightReward[iPos] = flGetClampedValue(key, "JumpHeightReward", "Jump Height Reward", "Jump_Height_Reward", "jumpheight", g_esGeneral.g_flJumpHeightReward[iPos], sSet[iPos], 0.0, 99999.0);
							g_esGeneral.g_flLoopingVoicelineInterval[iPos] = flGetClampedValue(key, "LoopingVoicelineInterval", "Looping Voiceline Interval", "Looping_Voiceline_Interval", "loopinterval", g_esGeneral.g_flLoopingVoicelineInterval[iPos], sSet[iPos], 0.1, 99999.0);
							g_esGeneral.g_flPipeBombDurationReward[iPos] = flGetClampedValue(key, "PipebombDurationReward", "Pipebomb Duration Reward", "Pipebomb_Duration_Reward", "pipeduration", g_esGeneral.g_flPipeBombDurationReward[iPos], sSet[iPos], 0.0, 99999.0);
							g_esGeneral.g_flPunchResistanceReward[iPos] = flGetClampedValue(key, "PunchResistanceReward", "Punch Resistance Reward", "Punch_Resistance_Reward", "punchres", g_esGeneral.g_flPunchResistanceReward[iPos], sSet[iPos], 0.0, 1.0);
							g_esGeneral.g_flShoveDamageReward[iPos] = flGetClampedValue(key, "ShoveDamageReward", "Shove Damage Reward", "Shove_Damage_Reward", "shovedmg", g_esGeneral.g_flShoveDamageReward[iPos], sSet[iPos], 0.0, 99999.0);
							g_esGeneral.g_flShoveRateReward[iPos] = flGetClampedValue(key, "ShoveRateReward", "Shove Rate Reward", "Shove_Rate_Reward", "shoverate", g_esGeneral.g_flShoveRateReward[iPos], sSet[iPos], 0.0, 99999.0);
							g_esGeneral.g_flSpeedBoostReward[iPos] = flGetClampedValue(key, "SpeedBoostReward", "Speed Boost Reward", "Speed_Boost_Reward", "speedboost", g_esGeneral.g_flSpeedBoostReward[iPos], sSet[iPos], 0.0, 99999.0);
							g_esGeneral.g_iRewardEnabled[iPos] = iGetClampedValue(key, "RewardEnabled", "Reward Enabled", "Reward_Enabled", "renabled", g_esGeneral.g_iRewardEnabled[iPos], sSet[iPos], -1, 2147483647);
							g_esGeneral.g_iRewardBots[iPos] = iGetClampedValue(key, "RewardBots", "Reward Bots", "Reward_Bots", "bots", g_esGeneral.g_iRewardBots[iPos], sSet[iPos], -1, 2147483647);
							g_esGeneral.g_iRewardEffect[iPos] = iGetClampedValue(key, "RewardEffect", "Reward Effect", "Reward_Effect", "effect", g_esGeneral.g_iRewardEffect[iPos], sSet[iPos], 0, 15);
							g_esGeneral.g_iRewardNotify[iPos] = iGetClampedValue(key, "RewardNotify", "Reward Notify", "Reward_Notify", "rnotify", g_esGeneral.g_iRewardNotify[iPos], sSet[iPos], 0, 3);
							g_esGeneral.g_iRewardVisual[iPos] = iGetClampedValue(key, "RewardVisual", "Reward Visual", "Reward_Visual", "visual", g_esGeneral.g_iRewardVisual[iPos], sSet[iPos], 0, 63);
							g_esGeneral.g_iAmmoBoostReward[iPos] = iGetClampedValue(key, "AmmoBoostReward", "Ammo Boost Reward", "Ammo_Boost_Reward", "ammoboost", g_esGeneral.g_iAmmoBoostReward[iPos], sSet[iPos], 0, 1);
							g_esGeneral.g_iAmmoRegenReward[iPos] = iGetClampedValue(key, "AmmoRegenReward", "Ammo Regen Reward", "Ammo_Regen_Reward", "ammoregen", g_esGeneral.g_iAmmoRegenReward[iPos], sSet[iPos], 0, 99999);
							g_esGeneral.g_iBunnyHopReward[iPos] = iGetClampedValue(key, "BunnyHopReward", "Bunny Hop Reward", "Bunny_Hop_Reward", "bhop", g_esGeneral.g_iBunnyHopReward[iPos], sSet[iPos], 0, 1);
							g_esGeneral.g_iBurstDoorsReward[iPos] = iGetClampedValue(key, "BurstDoorsReward", "Burst Doors Reward", "Burst_Doors_Reward", "burstdoors", g_esGeneral.g_iBurstDoorsReward[iPos], sSet[iPos], 0, 1);
							g_esGeneral.g_iCleanKillsReward[iPos] = iGetClampedValue(key, "CleanKillsReward", "Clean Kills Reward", "Clean_Kills_Reward", "cleankills", g_esGeneral.g_iCleanKillsReward[iPos], sSet[iPos], 0, 1);
							g_esGeneral.g_iFriendlyFireReward[iPos] = iGetClampedValue(key, "FriendlyFireReward", "Friendly Fire Reward", "Friendly_Fire_Reward", "friendlyfire", g_esGeneral.g_iFriendlyFireReward[iPos], sSet[iPos], 0, 1);
							g_esGeneral.g_iHealthRegenReward[iPos] = iGetClampedValue(key, "HealthRegenReward", "Health Regen Reward", "Health_Regen_Reward", "hpregen", g_esGeneral.g_iHealthRegenReward[iPos], sSet[iPos], 0, MT_MAXHEALTH);
							g_esGeneral.g_iHollowpointAmmoReward[iPos] = iGetClampedValue(key, "HollowpointAmmoReward", "Hollowpoint Ammo Reward", "Hollowpoint_Ammo_Reward", "hollowpoint", g_esGeneral.g_iHollowpointAmmoReward[iPos], sSet[iPos], 0, 1);
							g_esGeneral.g_iInextinguishableFireReward[iPos] = iGetClampedValue(key, "InextinguishableFireReward", "Inextinguishable Fire Reward", "Inextinguishable_Fire_Reward", "inexfire", g_esGeneral.g_iInextinguishableFireReward[iPos], sSet[iPos], 0, 1);
							g_esGeneral.g_iInfiniteAmmoReward[iPos] = iGetClampedValue(key, "InfiniteAmmoReward", "Infinite Ammo Reward", "Infinite_Ammo_Reward", "infammo", g_esGeneral.g_iInfiniteAmmoReward[iPos], sSet[iPos], 0, 31);
							g_esGeneral.g_iLadderActionsReward[iPos] = iGetClampedValue(key, "LadderActionsReward", "Ladder Actions Reward", "Ladder_Action_Reward", "ladderactions", g_esGeneral.g_iLadderActionsReward[iPos], sSet[iPos], 0, 1);
							g_esGeneral.g_iLadyKillerReward[iPos] = iGetClampedValue(key, "LadyKillerReward", "Lady Killer Reward", "Lady_Killer_Reward", "ladykiller", g_esGeneral.g_iLadyKillerReward[iPos], sSet[iPos], 0, 1);
							g_esGeneral.g_iLifeLeechReward[iPos] = iGetClampedValue(key, "LifeLeechReward", "Life Leech Reward", "Life_Leech_Reward", "lifeleech", g_esGeneral.g_iLifeLeechReward[iPos], sSet[iPos], 0, MT_MAXHEALTH);
							g_esGeneral.g_iMeleeRangeReward[iPos] = iGetClampedValue(key, "MeleeRangeReward", "Melee Range Reward", "Melee_Range_Reward", "meleerange", g_esGeneral.g_iMeleeRangeReward[iPos], sSet[iPos], 0, 99999);
							g_esGeneral.g_iMidairDashesReward[iPos] = iGetClampedValue(key, "MidairDashesReward", "Midair Dashes Reward", "Midair_Dashes_Reward", "midairdashes", g_esGeneral.g_iMidairDashesReward[iPos], sSet[iPos], 0, 99999);
							g_esGeneral.g_iParticleEffectVisual[iPos] = iGetClampedValue(key, "ParticleEffectVisual", "Particle Effect Visual", "Particle_Effect_Visual", "particle", g_esGeneral.g_iParticleEffectVisual[iPos], sSet[iPos], 0, 15);
							g_esGeneral.g_iPrefsNotify[iPos] = iGetClampedValue(key, "PrefsNotify", "Prefs Notify", "Prefs_Notify", "pnotify", g_esGeneral.g_iPrefsNotify[iPos], sSet[iPos], 0, 1);
							g_esGeneral.g_iRecoilDampenerReward[iPos] = iGetClampedValue(key, "RecoilDampenerReward", "Recoil Dampener Reward", "Recoil_Dampener_Reward", "recoil", g_esGeneral.g_iRecoilDampenerReward[iPos], sSet[iPos], 0, 1);
							g_esGeneral.g_iRespawnLoadoutReward[iPos] = iGetClampedValue(key, "RespawnLoadoutReward", "Respawn Loadout Reward", "Respawn_Loadout_Reward", "resloadout", g_esGeneral.g_iRespawnLoadoutReward[iPos], sSet[iPos], 0, 1);
							g_esGeneral.g_iReviveHealthReward[iPos] = iGetClampedValue(key, "ReviveHealthReward", "Revive Health Reward", "Revive_Health_Reward", "revivehp", g_esGeneral.g_iReviveHealthReward[iPos], sSet[iPos], 0, MT_MAXHEALTH);
							g_esGeneral.g_iShareRewards[iPos] = iGetClampedValue(key, "ShareRewards", "Share Rewards", "Share_Rewards", "share", g_esGeneral.g_iShareRewards[iPos], sSet[iPos], 0, 3);
							g_esGeneral.g_iShovePenaltyReward[iPos] = iGetClampedValue(key, "ShovePenaltyReward", "Shove Penalty Reward", "Shove_Penalty_Reward", "shovepenalty", g_esGeneral.g_iShovePenaltyReward[iPos], sSet[iPos], 0, 1);
							g_esGeneral.g_iSledgehammerRoundsReward[iPos] = iGetClampedValue(key, "SledgehammerRoundsReward", "Sledgehammer Rounds Reward", "Sledgehammer_Rounds_Reward", "sledgehammer", g_esGeneral.g_iSledgehammerRoundsReward[iPos], sSet[iPos], 0, 1);
							g_esGeneral.g_iSpecialAmmoReward[iPos] = iGetClampedValue(key, "SpecialAmmoReward", "Special Ammo Reward", "Special_Ammo_Reward", "specialammo", g_esGeneral.g_iSpecialAmmoReward[iPos], sSet[iPos], 0, 3);
							g_esGeneral.g_iStackRewards[iPos] = iGetClampedValue(key, "StackRewards", "Stack Rewards", "Stack_Rewards", "stack", g_esGeneral.g_iStackRewards[iPos], sSet[iPos], 0, 2147483647);
							g_esGeneral.g_iThornsReward[iPos] = iGetClampedValue(key, "ThornsReward", "Thorns Reward", "Thorns_Reward", "thorns", g_esGeneral.g_iThornsReward[iPos], sSet[iPos], 0, 1);
							g_esGeneral.g_iUsefulRewards[iPos] = iGetClampedValue(key, "UsefulRewards", "Useful Rewards", "Useful_Rewards", "useful", g_esGeneral.g_iUsefulRewards[iPos], sSet[iPos], 0, 15);
							g_esGeneral.g_iVoicePitchVisual[iPos] = iGetClampedValue(key, "VoicePitchVisual", "Voice Pitch Visual", "Voice_Pitch_Visual", "voicepitch", g_esGeneral.g_iVoicePitchVisual[iPos], sSet[iPos], 0, 255);

							vGetConfigColors(sValue, sizeof sValue, sSet[iPos], ';');
							vGetStringValue(key, "BodyColorVisual", "Body Color Visual", "Body_Color_Visual", "bodycolor", iPos, g_esGeneral.g_sBodyColorVisual, sizeof esGeneral::g_sBodyColorVisual, g_esGeneral.g_sBodyColorVisual2, sizeof esGeneral::g_sBodyColorVisual2, g_esGeneral.g_sBodyColorVisual3, sizeof esGeneral::g_sBodyColorVisual3, g_esGeneral.g_sBodyColorVisual4, sizeof esGeneral::g_sBodyColorVisual4, sValue);
							vGetStringValue(key, "FallVoicelineReward", "Fall Voiceline Reward", "Fall_Voiceline_Reward", "fallvoice", iPos, g_esGeneral.g_sFallVoicelineReward, sizeof esGeneral::g_sFallVoicelineReward, g_esGeneral.g_sFallVoicelineReward2, sizeof esGeneral::g_sFallVoicelineReward2, g_esGeneral.g_sFallVoicelineReward3, sizeof esGeneral::g_sFallVoicelineReward3, g_esGeneral.g_sFallVoicelineReward4, sizeof esGeneral::g_sFallVoicelineReward4, sSet[iPos]);
							vGetStringValue(key, "GlowColorVisual", "Glow Color Visual", "Glow_Color_Visual", "glowcolor", iPos, g_esGeneral.g_sOutlineColorVisual, sizeof esGeneral::g_sOutlineColorVisual, g_esGeneral.g_sOutlineColorVisual2, sizeof esGeneral::g_sOutlineColorVisual2, g_esGeneral.g_sOutlineColorVisual3, sizeof esGeneral::g_sOutlineColorVisual3, g_esGeneral.g_sOutlineColorVisual4, sizeof esGeneral::g_sOutlineColorVisual4, sValue);
							vGetStringValue(key, "ItemReward", "Item Reward", "Item_Reward", "item", iPos, g_esGeneral.g_sItemReward, sizeof esGeneral::g_sItemReward, g_esGeneral.g_sItemReward2, sizeof esGeneral::g_sItemReward2, g_esGeneral.g_sItemReward3, sizeof esGeneral::g_sItemReward3, g_esGeneral.g_sItemReward4, sizeof esGeneral::g_sItemReward4, sSet[iPos]);
							vGetStringValue(key, "LightColorVisual", "Light Color Visual", "Light_Color_Visual", "lightcolor", iPos, g_esGeneral.g_sLightColorVisual, sizeof esGeneral::g_sLightColorVisual, g_esGeneral.g_sLightColorVisual2, sizeof esGeneral::g_sLightColorVisual2, g_esGeneral.g_sLightColorVisual3, sizeof esGeneral::g_sLightColorVisual3, g_esGeneral.g_sLightColorVisual4, sizeof esGeneral::g_sLightColorVisual4, sValue);
							vGetStringValue(key, "LoopingVoicelineVisual", "Looping Voiceline Visual", "Looping_Voiceline_Visual", "loopvoice", iPos, g_esGeneral.g_sLoopingVoicelineVisual, sizeof esGeneral::g_sLoopingVoicelineVisual, g_esGeneral.g_sLoopingVoicelineVisual2, sizeof esGeneral::g_sLoopingVoicelineVisual2, g_esGeneral.g_sLoopingVoicelineVisual3, sizeof esGeneral::g_sLoopingVoicelineVisual3, g_esGeneral.g_sLoopingVoicelineVisual4, sizeof esGeneral::g_sLoopingVoicelineVisual4, sSet[iPos]);
							vGetStringValue(key, "ScreenColorVisual", "Screen Color Visual", "Screen_Color_Visual", "screencolor", iPos, g_esGeneral.g_sScreenColorVisual, sizeof esGeneral::g_sScreenColorVisual, g_esGeneral.g_sScreenColorVisual2, sizeof esGeneral::g_sScreenColorVisual2, g_esGeneral.g_sScreenColorVisual3, sizeof esGeneral::g_sScreenColorVisual3, g_esGeneral.g_sScreenColorVisual4, sizeof esGeneral::g_sScreenColorVisual4, sValue);
						}

						g_esGeneral.g_iStackLimits[iPos] = iGetClampedValue(key, "StackLimits", "Stack Limits", "Stack_Limits", "limits", g_esGeneral.g_iStackLimits[iPos], sSet[iPos], 0, 99999);
					}
				}
				else if (StrEqual(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_DIFF, false) || StrEqual(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_DIFF2, false))
				{
					if (StrEqual(key, "DifficultyDamage", false) || StrEqual(key, "Difficulty Damage", false) || StrEqual(key, "Difficulty_Damage", false) || StrEqual(key, "diffdmg", false))
					{
						char sValue[36], sSet[4][9];
						strcopy(sValue, sizeof sValue, value);
						ReplaceString(sValue, sizeof sValue, " ", "");
						ExplodeString(sValue, ",", sSet, sizeof sSet, sizeof sSet[]);
						for (int iPos = 0; iPos < (sizeof esGeneral::g_flDifficultyDamage); iPos++)
						{
							g_esGeneral.g_flDifficultyDamage[iPos] = (sSet[iPos][0] != '\0') ? flClamp(StringToFloat(sSet[iPos]), 0.0, 99999.0) : g_esGeneral.g_flDifficultyDamage[iPos];
						}
					}
				}
				else if (StrEqual(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_WAVES, false))
				{
					if (StrEqual(key, "RegularType", false) || StrEqual(key, "Regular Type", false) || StrEqual(key, "Regular_Type", false) || StrEqual(key, "regtype", false))
					{
						char sValue[10], sRange[2][5];
						strcopy(sValue, sizeof sValue, value);
						ReplaceString(sValue, sizeof sValue, " ", "");
						ExplodeString(sValue, "-", sRange, sizeof sRange, sizeof sRange[]);

						g_esGeneral.g_iRegularMinType = (sRange[0][0] != '\0') ? iClamp(StringToInt(sRange[0]), 0, MT_MAXTYPES) : g_esGeneral.g_iRegularMinType;
						g_esGeneral.g_iRegularMaxType = (sRange[1][0] != '\0') ? iClamp(StringToInt(sRange[1]), 0, MT_MAXTYPES) : g_esGeneral.g_iRegularMaxType;
					}
					else if (StrEqual(key, "FinaleTypes", false) || StrEqual(key, "Finale Types", false) || StrEqual(key, "Finale_Types", false) || StrEqual(key, "fintypes", false))
					{
						char sValue[110], sRange[11][10], sSet[2][5];
						strcopy(sValue, sizeof sValue, value);
						ReplaceString(sValue, sizeof sValue, " ", "");
						ExplodeString(sValue, ",", sRange, sizeof sRange, sizeof sRange[]);
						for (int iPos = 0; iPos < (sizeof sRange); iPos++)
						{
							if (sRange[iPos][0] == '\0')
							{
								continue;
							}

							ExplodeString(sRange[iPos], "-", sSet, sizeof sSet, sizeof sSet[]);
							g_esGeneral.g_iFinaleMinTypes[iPos] = (sSet[0][0] != '\0') ? iClamp(StringToInt(sSet[0]), 0, MT_MAXTYPES) : g_esGeneral.g_iFinaleMinTypes[iPos];
							g_esGeneral.g_iFinaleMaxTypes[iPos] = (sSet[1][0] != '\0') ? iClamp(StringToInt(sSet[1]), 0, MT_MAXTYPES) : g_esGeneral.g_iFinaleMaxTypes[iPos];
						}
					}
					else if (StrEqual(key, "FinaleWaves", false) || StrEqual(key, "Finale Waves", false) || StrEqual(key, "Finale_Waves", false) || StrEqual(key, "finwaves", false))
					{
						char sValue[33], sSet[11][3];
						strcopy(sValue, sizeof sValue, value);
						ReplaceString(sValue, sizeof sValue, " ", "");
						ExplodeString(sValue, ",", sSet, sizeof sSet, sizeof sSet[]);
						for (int iPos = 0; iPos < (sizeof esGeneral::g_iFinaleWave); iPos++)
						{
							g_esGeneral.g_iFinaleWave[iPos] = (sSet[iPos][0] != '\0') ? iClamp(StringToInt(sSet[iPos]), 0, 32) : g_esGeneral.g_iFinaleWave[iPos];
						}
					}
				}
				else if ((StrEqual(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_CONVARS, false) || StrEqual(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_CONVARS2, false)) && key[0] != '\0')
				{
					char sKey[128], sValue[PLATFORM_MAX_PATH];
					strcopy(sKey, sizeof sKey, key);
					ReplaceString(sKey, sizeof sKey, " ", "");

					strcopy(sValue, sizeof sValue, value);
					ReplaceString(sValue, sizeof sValue, " ", "");

					g_esGeneral.g_cvMTTempSetting = FindConVar(sKey);
					if (g_esGeneral.g_cvMTTempSetting != null)
					{
						if (g_esGeneral.g_cvMTTempSetting.Plugin != g_hPluginHandle)
						{
							int iFlags = g_esGeneral.g_cvMTTempSetting.Flags;
							g_esGeneral.g_cvMTTempSetting.Flags &= ~FCVAR_NOTIFY;
							g_esGeneral.g_cvMTTempSetting.SetString(sValue);
							g_esGeneral.g_cvMTTempSetting.Flags = iFlags;
							g_esGeneral.g_cvMTTempSetting = null;

							vLogMessage(MT_LOG_SERVER, _, "%s Changed cvar \"%s\" to \"%s\".", MT_TAG, sKey, sValue);
						}
						else
						{
							vLogMessage(MT_LOG_SERVER, _, "%s Unable to change cvar: %s", MT_TAG, sKey);
						}
					}
					else
					{
						vLogMessage(MT_LOG_SERVER, _, "%s Unable to find cvar: %s", MT_TAG, sKey);
					}
				}

				if (g_esGeneral.g_iConfigMode == 1)
				{
					g_esGeneral.g_iGameModeTypes = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_GAMEMODES, MT_CONFIG_SECTION_GAMEMODES2, MT_CONFIG_SECTION_GAMEMODES3, MT_CONFIG_SECTION_GAMEMODES4, key, "GameModeTypes", "Game Mode Types", "Game_Mode_Types", "types", g_esGeneral.g_iGameModeTypes, value, 0, 15);
					g_esGeneral.g_iConfigEnable = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_CUSTOM, MT_CONFIG_SECTION_CUSTOM, MT_CONFIG_SECTION_CUSTOM, MT_CONFIG_SECTION_CUSTOM, key, "EnableCustomConfigs", "Enable Custom Configs", "Enable_Custom_Configs", "cenabled", g_esGeneral.g_iConfigEnable, value, 0, 1);
					g_esGeneral.g_iConfigCreate = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_CUSTOM, MT_CONFIG_SECTION_CUSTOM, MT_CONFIG_SECTION_CUSTOM, MT_CONFIG_SECTION_CUSTOM, key, "CreateConfigTypes", "Create Config Types", "Create_Config_Types", "create", g_esGeneral.g_iConfigCreate, value, 0, 255);
					g_esGeneral.g_flConfigDelay = flGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_CUSTOM, MT_CONFIG_SECTION_CUSTOM, MT_CONFIG_SECTION_CUSTOM, MT_CONFIG_SECTION_CUSTOM, key, "ExecuteConfigDelay", "Execute Config Delay", "Execute_Config_Delay", "delay", g_esGeneral.g_flConfigDelay, value, 0.1, 99999.0);
					g_esGeneral.g_iConfigExecute = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_CUSTOM, MT_CONFIG_SECTION_CUSTOM, MT_CONFIG_SECTION_CUSTOM, MT_CONFIG_SECTION_CUSTOM, key, "ExecuteConfigTypes", "Execute Config Types", "Execute_Config_Types", "execute", g_esGeneral.g_iConfigExecute, value, 0, 255);

					vGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_GAMEMODES, MT_CONFIG_SECTION_GAMEMODES2, MT_CONFIG_SECTION_GAMEMODES3, MT_CONFIG_SECTION_GAMEMODES4, key, "EnabledGameModes", "Enabled Game Modes", "Enabled_Game_Modes", "gmenabled", g_esGeneral.g_sEnabledGameModes, sizeof esGeneral::g_sEnabledGameModes, value);
					vGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_GAMEMODES, MT_CONFIG_SECTION_GAMEMODES2, MT_CONFIG_SECTION_GAMEMODES3, MT_CONFIG_SECTION_GAMEMODES4, key, "DisabledGameModes", "Disabled Game Modes", "Disabled_Game_Modes", "gmdisabled", g_esGeneral.g_sDisabledGameModes, sizeof esGeneral::g_sDisabledGameModes, value);
				}

				vConfigsLoadedForward(g_esGeneral.g_sCurrentSubSection, key, value, 0, -1, g_esGeneral.g_iConfigMode);
			}
			else if (!strncmp(g_esGeneral.g_sCurrentSection, "Tank", 4, false) || g_esGeneral.g_sCurrentSection[0] == '#' || IsCharNumeric(g_esGeneral.g_sCurrentSection[0]) || StrContains(g_esGeneral.g_sCurrentSection, "all", false) != -1 || FindCharInString(g_esGeneral.g_sCurrentSection, ',') != -1 || FindCharInString(g_esGeneral.g_sCurrentSection, '-') != -1)
			{
				if (!strncmp(g_esGeneral.g_sCurrentSection, "Tank", 4, false) || g_esGeneral.g_sCurrentSection[0] == '#')
				{
					vReadTankSettings(g_esGeneral.g_sCurrentSubSection, key, value);
				}
				else if (IsCharNumeric(g_esGeneral.g_sCurrentSection[0]) || StrContains(g_esGeneral.g_sCurrentSection, "all", false) != -1 || FindCharInString(g_esGeneral.g_sCurrentSection, ',') != -1 || FindCharInString(g_esGeneral.g_sCurrentSection, '-') != -1)
				{
					if (IsCharNumeric(g_esGeneral.g_sCurrentSection[0]) && FindCharInString(g_esGeneral.g_sCurrentSection, ',') == -1 && FindCharInString(g_esGeneral.g_sCurrentSection, '-') == -1)
					{
						vReadTankSettings(g_esGeneral.g_sCurrentSubSection, key, value);
					}
					else if (StrContains(g_esGeneral.g_sCurrentSection, "all", false) != -1 || FindCharInString(g_esGeneral.g_sCurrentSection, ',') != -1 || FindCharInString(g_esGeneral.g_sCurrentSection, '-') != -1)
					{
						int iRealType = 0;
						for (int iIndex = g_esGeneral.g_iMinType; iIndex <= g_esGeneral.g_iMaxType; iIndex++)
						{
							if (iIndex <= 0)
							{
								continue;
							}

							iRealType = iFindSectionType(g_esGeneral.g_sCurrentSection, iIndex);
							if (iIndex == g_esTank[iRealType].g_iRecordedType[0] || StrContains(g_esGeneral.g_sCurrentSection, "all", false) != -1)
							{
								vReadTankSettings(g_esGeneral.g_sCurrentSubSection, key, value);
							}
						}
					}
				}
			}
		}
		else if (g_esGeneral.g_iConfigMode == 3 && (!strncmp(g_esGeneral.g_sCurrentSection, "STEAM_", 6, false) || !strncmp("0:", g_esGeneral.g_sCurrentSection, 2) || !strncmp("1:", g_esGeneral.g_sCurrentSection, 2) || (!strncmp(g_esGeneral.g_sCurrentSection, "[U:", 3) && g_esGeneral.g_sCurrentSection[strlen(g_esGeneral.g_sCurrentSection) - 1] == ']')))
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (bIsValidClient(iPlayer, MT_CHECK_INGAME|MT_CHECK_FAKECLIENT))
				{
					if (StrEqual(g_esPlayer[iPlayer].g_sSteamID32, g_esGeneral.g_sCurrentSection, false) || StrEqual(g_esPlayer[iPlayer].g_sSteam3ID, g_esGeneral.g_sCurrentSection, false))
					{
						g_esPlayer[iPlayer].g_iTankModel = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, key, "TankModel", "Tank Model", "Tank_Model", "model", g_esPlayer[iPlayer].g_iTankModel, value, 0, 7);
						g_esPlayer[iPlayer].g_flBurnDuration = flGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, key, "BurnDuration", "Burn Duration", "Burn_Duration", "burndur", g_esPlayer[iPlayer].g_flBurnDuration, value, 0.0, 99999.0);
						g_esPlayer[iPlayer].g_flBurntSkin = flGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, key, "BurntSkin", "Burnt Skin", "Burnt_Skin", "burnt", g_esPlayer[iPlayer].g_flBurntSkin, value, -1.0, 1.0);
						g_esPlayer[iPlayer].g_iTankNote = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, key, "TankNote", "Tank Note", "Tank_Note", "note", g_esPlayer[iPlayer].g_iTankNote, value, 0, 1);
						g_esPlayer[iPlayer].g_iCheckAbilities = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, key, "CheckAbilities", "Check Abilities", "Check_Abilities", "check", g_esPlayer[iPlayer].g_iCheckAbilities, value, 0, 1);
						g_esPlayer[iPlayer].g_iDeathRevert = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, key, "DeathRevert", "Death Revert", "Death_Revert", "revert", g_esPlayer[iPlayer].g_iDeathRevert, value, 0, 1);
						g_esPlayer[iPlayer].g_iAnnounceArrival = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE2, key, "AnnounceArrival", "Announce Arrival", "Announce_Arrival", "arrival", g_esPlayer[iPlayer].g_iAnnounceArrival, value, 0, 31);
						g_esPlayer[iPlayer].g_iAnnounceDeath = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE2, key, "AnnounceDeath", "Announce Death", "Announce_Death", "death", g_esPlayer[iPlayer].g_iAnnounceDeath, value, 0, 2);
						g_esPlayer[iPlayer].g_iAnnounceKill = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE2, key, "AnnounceKill", "Announce Kill", "Announce_Kill", "kill", g_esPlayer[iPlayer].g_iAnnounceKill, value, 0, 1);
						g_esPlayer[iPlayer].g_iArrivalMessage = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE2, key, "ArrivalMessage", "Arrival Message", "Arrival_Message", "arrivalmsg", g_esPlayer[iPlayer].g_iArrivalMessage, value, 0, 1023);
						g_esPlayer[iPlayer].g_iArrivalSound = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE2, key, "ArrivalSound", "Arrival Sound", "Arrival_Sound", "arrivalsnd", g_esPlayer[iPlayer].g_iArrivalSound, value, 0, 1);
						g_esPlayer[iPlayer].g_iDeathDetails = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE2, key, "DeathDetails", "Death Details", "Death_Details", "deathdets", g_esPlayer[iPlayer].g_iDeathDetails, value, 0, 5);
						g_esPlayer[iPlayer].g_iDeathMessage = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE2, key, "DeathMessage", "Death Message", "Death_Message", "deathmsg", g_esPlayer[iPlayer].g_iDeathMessage, value, 0, 1023);
						g_esPlayer[iPlayer].g_iDeathSound = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE2, key, "DeathSound", "Death Sound", "Death_Sound", "deathsnd", g_esPlayer[iPlayer].g_iDeathSound, value, 0, 1);
						g_esPlayer[iPlayer].g_iKillMessage = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE2, key, "KillMessage", "Kill Message", "Kill_Message", "killmsg", g_esPlayer[iPlayer].g_iKillMessage, value, 0, 1023);
						g_esPlayer[iPlayer].g_iVocalizeArrival = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE2, key, "VocalizeArrival", "Vocalize Arrival", "Vocalize_Arrival", "arrivalvoc", g_esPlayer[iPlayer].g_iVocalizeArrival, value, 0, 1);
						g_esPlayer[iPlayer].g_iVocalizeDeath = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE, MT_CONFIG_SECTION_ANNOUNCE2, key, "VocalizeDeath", "Vocalize Death", "Vocalize_Death", "deathvoc", g_esPlayer[iPlayer].g_iVocalizeDeath, value, 0, 1);
						g_esPlayer[iPlayer].g_iTeammateLimit = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_REWARDS, MT_CONFIG_SECTION_REWARDS, MT_CONFIG_SECTION_REWARDS, MT_CONFIG_SECTION_REWARDS, key, "TeammateLimit", "Teammate Limit", "Teammate_Limit", "teamlimit", g_esPlayer[iPlayer].g_iTeammateLimit, value, 0, 32);
						g_esPlayer[iPlayer].g_iGlowEnabled = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_GLOW, MT_CONFIG_SECTION_GLOW, MT_CONFIG_SECTION_GLOW, MT_CONFIG_SECTION_GLOW, key, "GlowEnabled", "Glow Enabled", "Glow_Enabled", "genabled", g_esPlayer[iPlayer].g_iGlowEnabled, value, 0, 1);
						g_esPlayer[iPlayer].g_iGlowFlashing = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_GLOW, MT_CONFIG_SECTION_GLOW, MT_CONFIG_SECTION_GLOW, MT_CONFIG_SECTION_GLOW, key, "GlowFlashing", "Glow Flashing", "Glow_Flashing", "flashing", g_esPlayer[iPlayer].g_iGlowFlashing, value, 0, 1);
						g_esPlayer[iPlayer].g_iGlowType = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_GLOW, MT_CONFIG_SECTION_GLOW, MT_CONFIG_SECTION_GLOW, MT_CONFIG_SECTION_GLOW, key, "GlowType", "Glow Type", "Glow_Type", "type", g_esPlayer[iPlayer].g_iGlowType, value, 0, 1);
						g_esPlayer[iPlayer].g_iBaseHealth = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, key, "BaseHealth", "Base Health", "Base_Health", "basehp", g_esPlayer[iPlayer].g_iBaseHealth, value, 0, MT_MAXHEALTH);
						g_esPlayer[iPlayer].g_iDisplayHealth = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, key, "DisplayHealth", "Display Health", "Display_Health", "displayhp", g_esPlayer[iPlayer].g_iDisplayHealth, value, 0, 11);
						g_esPlayer[iPlayer].g_iDisplayHealthType = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, key, "DisplayHealthType", "Display Health Type", "Display_Health_Type", "displaytype", g_esPlayer[iPlayer].g_iDisplayHealthType, value, 0, 2);
						g_esPlayer[iPlayer].g_iExtraHealth = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, key, "ExtraHealth", "Extra Health", "Extra_Health", "extrahp", g_esPlayer[iPlayer].g_iExtraHealth, value, MT_MAX_HEALTH_REDUCTION, MT_MAXHEALTH);
						g_esPlayer[iPlayer].g_flHealPercentMultiplier = flGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, key, "HealthPercentageMultiplier", "Health Percentage Multiplier", "Health_Percentage_Multiplier", "hpmulti", g_esPlayer[iPlayer].g_flHealPercentMultiplier, value, 1.0, 99999.0);
						g_esPlayer[iPlayer].g_iHumanMultiplierMode = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, key, "HumanMultiplierMode", "Human Multiplier Mode", "Human_Multiplier_Mode", "humanmultimode", g_esPlayer[iPlayer].g_iHumanMultiplierMode, value, 0, 1);
						g_esPlayer[iPlayer].g_iMinimumHumans = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, key, "MinimumHumans", "Minimum Humans", "Minimum_Humans", "minhumans", g_esPlayer[iPlayer].g_iMinimumHumans, value, 1, 32);
						g_esPlayer[iPlayer].g_iMultiplyHealth = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, key, "MultiplyHealth", "Multiply Health", "Multiply_Health", "multihp", g_esPlayer[iPlayer].g_iMultiplyHealth, value, 0, 3);
						g_esPlayer[iPlayer].g_iBossStages = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_BOSS, MT_CONFIG_SECTION_BOSS, MT_CONFIG_SECTION_BOSS, MT_CONFIG_SECTION_BOSS, key, "BossStages", "Boss Stages", "Boss_Stages", "bossstages", g_esPlayer[iPlayer].g_iBossStages, value, 1, 4);
						g_esPlayer[iPlayer].g_iRandomTank = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_RANDOM, MT_CONFIG_SECTION_RANDOM, MT_CONFIG_SECTION_RANDOM, MT_CONFIG_SECTION_RANDOM, key, "RandomTank", "Random Tank", "Random_Tank", "random", g_esPlayer[iPlayer].g_iRandomTank, value, 0, 1);
						g_esPlayer[iPlayer].g_flRandomDuration = flGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_RANDOM, MT_CONFIG_SECTION_RANDOM, MT_CONFIG_SECTION_RANDOM, MT_CONFIG_SECTION_RANDOM, key, "RandomDuration", "Random Duration", "Random_Duration", "randduration", g_esPlayer[iPlayer].g_flRandomDuration, value, 0.1, 99999.0);
						g_esPlayer[iPlayer].g_flRandomInterval = flGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_RANDOM, MT_CONFIG_SECTION_RANDOM, MT_CONFIG_SECTION_RANDOM, MT_CONFIG_SECTION_RANDOM, key, "RandomInterval", "Random Interval", "Random_Interval", "randinterval", g_esPlayer[iPlayer].g_flRandomInterval, value, 0.1, 99999.0);
						g_esPlayer[iPlayer].g_flTransformDelay = flGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_TRANSFORM, MT_CONFIG_SECTION_TRANSFORM, MT_CONFIG_SECTION_TRANSFORM, MT_CONFIG_SECTION_TRANSFORM, key, "TransformDelay", "Transform Delay", "Transform_Delay", "transdelay", g_esPlayer[iPlayer].g_flTransformDelay, value, 0.1, 99999.0);
						g_esPlayer[iPlayer].g_flTransformDuration = flGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_TRANSFORM, MT_CONFIG_SECTION_TRANSFORM, MT_CONFIG_SECTION_TRANSFORM, MT_CONFIG_SECTION_TRANSFORM, key, "TransformDuration", "Transform Duration", "Transform_Duration", "transduration", g_esPlayer[iPlayer].g_flTransformDuration, value, 0.1, 99999.0);
						g_esPlayer[iPlayer].g_iSpawnType = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_SPAWN, MT_CONFIG_SECTION_SPAWN, MT_CONFIG_SECTION_SPAWN, MT_CONFIG_SECTION_SPAWN, key, "SpawnType", "Spawn Type", "Spawn_Type", "spawntype", g_esPlayer[iPlayer].g_iSpawnType, value, 0, 4);
						g_esPlayer[iPlayer].g_iRockModel = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_PROPS, MT_CONFIG_SECTION_PROPS, MT_CONFIG_SECTION_PROPS, MT_CONFIG_SECTION_PROPS, key, "RockModel", "Rock Model", "Rock_Model", "rockmodel", g_esPlayer[iPlayer].g_iRockModel, value, 0, 2);
						g_esPlayer[iPlayer].g_iPropsAttached = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_PROPS, MT_CONFIG_SECTION_PROPS, MT_CONFIG_SECTION_PROPS, MT_CONFIG_SECTION_PROPS, key, "PropsAttached", "Props Attached", "Props_Attached", "attached", g_esPlayer[iPlayer].g_iPropsAttached, value, 0, 511);
						g_esPlayer[iPlayer].g_iBodyEffects = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_PARTICLES, MT_CONFIG_SECTION_PARTICLES, MT_CONFIG_SECTION_PARTICLES, MT_CONFIG_SECTION_PARTICLES, key, "BodyEffects", "Body Effects", "Body_Effects", "body", g_esPlayer[iPlayer].g_iBodyEffects, value, 0, 127);
						g_esPlayer[iPlayer].g_iRockEffects = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_PARTICLES, MT_CONFIG_SECTION_PARTICLES, MT_CONFIG_SECTION_PARTICLES, MT_CONFIG_SECTION_PARTICLES, key, "RockEffects", "Rock Effects", "Rock_Effects", "rock", g_esPlayer[iPlayer].g_iRockEffects, value, 0, 15);
						g_esPlayer[iPlayer].g_flAttackInterval = flGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE2, key, "AttackInterval", "Attack Interval", "Attack_Interval", "attack", g_esPlayer[iPlayer].g_flAttackInterval, value, 0.0, 99999.0);
						g_esPlayer[iPlayer].g_flClawDamage = flGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE2, key, "ClawDamage", "Claw Damage", "Claw_Damage", "claw", g_esPlayer[iPlayer].g_flClawDamage, value, -1.0, 99999.0);
						g_esPlayer[iPlayer].g_iGroundPound = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE2, key, "GroundPound", "Ground Pound", "Ground_Pound", "pound", g_esPlayer[iPlayer].g_iGroundPound, value, 0, 1);
						g_esPlayer[iPlayer].g_flHittableDamage = flGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE2, key, "HittableDamage", "Hittable Damage", "Hittable_Damage", "hittable", g_esPlayer[iPlayer].g_flHittableDamage, value, -1.0, 99999.0);
						g_esPlayer[iPlayer].g_flIncapDamageMultiplier = flGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE2, key, "IncapDamageMultiplier", "Incap Damage Multiplier", "Incap_Damage_Multiplier", "incapdmgmulti", g_esPlayer[iPlayer].g_flIncapDamageMultiplier, value, 1.0, 99999.0);
						g_esPlayer[iPlayer].g_flPunchForce = flGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE2, key, "PunchForce", "Punch Force", "Punch_Force", "punchf", g_esPlayer[iPlayer].g_flPunchForce, value, -1.0, 99999.0);
						g_esPlayer[iPlayer].g_flPunchThrow = flGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE2, key, "PunchThrow", "Punch Throw", "Punch_Throw", "puncht", g_esPlayer[iPlayer].g_flPunchThrow, value, 0.0, 100.0);
						g_esPlayer[iPlayer].g_flRockDamage = flGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE2, key, "RockDamage", "Rock Damage", "Rock_Damage", "rockdmg", g_esPlayer[iPlayer].g_flRockDamage, value, -1.0, 99999.0);
						g_esPlayer[iPlayer].g_iRockSound = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE2, key, "RockSound", "Rock Sound", "Rock_Sound", "rocksnd", g_esPlayer[iPlayer].g_iRockSound, value, 0, 1);
						g_esPlayer[iPlayer].g_flRunSpeed = flGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE2, key, "RunSpeed", "Run Speed", "Run_Speed", "speed", g_esPlayer[iPlayer].g_flRunSpeed, value, 0.0, 3.0);
						g_esPlayer[iPlayer].g_iSkipIncap = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE2, key, "SkipIncap", "Skip Incap", "Skip_Incap", "incap", g_esPlayer[iPlayer].g_iSkipIncap, value, 0, 1);
						g_esPlayer[iPlayer].g_iSkipTaunt = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE2, key, "SkipTaunt", "Skip Taunt", "Skip_Taunt", "taunt", g_esPlayer[iPlayer].g_iSkipTaunt, value, 0, 1);
						g_esPlayer[iPlayer].g_iSweepFist = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE2, key, "SweepFist", "Sweep Fist", "Sweep_Fist", "sweep", g_esPlayer[iPlayer].g_iSweepFist, value, 0, 1);
						g_esPlayer[iPlayer].g_flThrowInterval = flGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE, MT_CONFIG_SECTION_ENHANCE2, key, "ThrowInterval", "Throw Interval", "Throw_Interval", "throw", g_esPlayer[iPlayer].g_flThrowInterval, value, 0.0, 99999.0);
						g_esPlayer[iPlayer].g_iBulletImmunity = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_IMMUNE, MT_CONFIG_SECTION_IMMUNE, MT_CONFIG_SECTION_IMMUNE, MT_CONFIG_SECTION_IMMUNE2, key, "BulletImmunity", "Bullet Immunity", "Bullet_Immunity", "bullet", g_esPlayer[iPlayer].g_iBulletImmunity, value, 0, 1);
						g_esPlayer[iPlayer].g_iExplosiveImmunity = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_IMMUNE, MT_CONFIG_SECTION_IMMUNE, MT_CONFIG_SECTION_IMMUNE, MT_CONFIG_SECTION_IMMUNE2, key, "ExplosiveImmunity", "Explosive Immunity", "Explosive_Immunity", "explosive", g_esPlayer[iPlayer].g_iExplosiveImmunity, value, 0, 1);
						g_esPlayer[iPlayer].g_iFireImmunity = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_IMMUNE, MT_CONFIG_SECTION_IMMUNE, MT_CONFIG_SECTION_IMMUNE, MT_CONFIG_SECTION_IMMUNE2, key, "FireImmunity", "Fire Immunity", "Fire_Immunity", "fire", g_esPlayer[iPlayer].g_iFireImmunity, value, 0, 1);
						g_esPlayer[iPlayer].g_iHittableImmunity = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_IMMUNE, MT_CONFIG_SECTION_IMMUNE, MT_CONFIG_SECTION_IMMUNE, MT_CONFIG_SECTION_IMMUNE2, key, "HittableImmunity", "Hittable Immunity", "Hittable_Immunity", "hittable", g_esPlayer[iPlayer].g_iHittableImmunity, value, 0, 1);
						g_esPlayer[iPlayer].g_iMeleeImmunity = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_IMMUNE, MT_CONFIG_SECTION_IMMUNE, MT_CONFIG_SECTION_IMMUNE, MT_CONFIG_SECTION_IMMUNE2, key, "MeleeImmunity", "Melee Immunity", "Melee_Immunity", "melee", g_esPlayer[iPlayer].g_iMeleeImmunity, value, 0, 1);
						g_esPlayer[iPlayer].g_iVomitImmunity = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_IMMUNE, MT_CONFIG_SECTION_IMMUNE, MT_CONFIG_SECTION_IMMUNE, MT_CONFIG_SECTION_IMMUNE2, key, "VomitImmunity", "Vomit Immunity", "Vomit_Immunity", "vomit", g_esPlayer[iPlayer].g_iVomitImmunity, value, 0, 1);
						g_esPlayer[iPlayer].g_iFavoriteType = iGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_ADMIN, MT_CONFIG_SECTION_ADMIN, MT_CONFIG_SECTION_ADMIN, MT_CONFIG_SECTION_ADMIN2, key, "FavoriteType", "Favorite Type", "Favorite_Type", "favorite", g_esPlayer[iPlayer].g_iFavoriteType, value, 0, g_esGeneral.g_iMaxType);
						g_esPlayer[iPlayer].g_iAccessFlags = iGetAdminFlagsValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_ADMIN, MT_CONFIG_SECTION_ADMIN, MT_CONFIG_SECTION_ADMIN, MT_CONFIG_SECTION_ADMIN2, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
						g_esPlayer[iPlayer].g_iImmunityFlags = iGetAdminFlagsValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_ADMIN, MT_CONFIG_SECTION_ADMIN, MT_CONFIG_SECTION_ADMIN, MT_CONFIG_SECTION_ADMIN2, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);

						vGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, MT_CONFIG_SECTION_HEALTH, key, "HealthCharacters", "Health Characters", "Health_Characters", "hpchars", g_esPlayer[iPlayer].g_sHealthCharacters, sizeof esPlayer::g_sHealthCharacters, value);
						vGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_COMBO, MT_CONFIG_SECTION_COMBO, MT_CONFIG_SECTION_COMBO, MT_CONFIG_SECTION_COMBO, key, "ComboSet", "Combo Set", "Combo_Set", "set", g_esPlayer[iPlayer].g_sComboSet, sizeof esPlayer::g_sComboSet, value);

						if (StrEqual(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_GENERAL, false))
						{
							if (StrEqual(key, "SkinColor", false) || StrEqual(key, "Skin Color", false) || StrEqual(key, "Skin_Color", false) || StrEqual(key, "skin", false))
							{
								char sValue[64], sSet[4][4];
								vGetConfigColors(sValue, sizeof sValue, value);
								strcopy(g_esPlayer[iPlayer].g_sSkinColor, sizeof esPlayer::g_sSkinColor, value);
								ReplaceString(sValue, sizeof sValue, " ", "");
								ExplodeString(sValue, ",", sSet, sizeof sSet, sizeof sSet[]);
								for (int iPos = 0; iPos < (sizeof esPlayer::g_iSkinColor); iPos++)
								{
									g_esPlayer[iPlayer].g_iSkinColor[iPos] = (sSet[iPos][0] != '\0' && StringToInt(sSet[iPos]) >= 0) ? iClamp(StringToInt(sSet[iPos]), 0, 255) : -1;
								}
							}
							else
							{
								vGetKeyValue(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, MT_CONFIG_SECTION_GENERAL, key, "TankName", "Tank Name", "Tank_Name", "name", g_esPlayer[iPlayer].g_sTankName, sizeof esPlayer::g_sTankName, value);
							}
						}
						else if (StrEqual(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_REWARDS, false))
						{
							char sValue[1280], sSet[7][320];
							strcopy(sValue, sizeof sValue, value);
							ReplaceString(sValue, sizeof sValue, " ", "");
							ExplodeString(sValue, ",", sSet, sizeof sSet, sizeof sSet[]);
							for (int iPos = 0; iPos < (sizeof esPlayer::g_iStackLimits); iPos++)
							{
								if (iPos < (sizeof esPlayer::g_iRewardEnabled))
								{
									g_esPlayer[iPlayer].g_flRewardChance[iPos] = flGetClampedValue(key, "RewardChance", "Reward Chance", "Reward_Chance", "chance", g_esPlayer[iPlayer].g_flRewardChance[iPos], sSet[iPos], 0.1, 100.0);
									g_esPlayer[iPlayer].g_flRewardDuration[iPos] = flGetClampedValue(key, "RewardDuration", "Reward Duration", "Reward_Duration", "duration", g_esPlayer[iPlayer].g_flRewardDuration[iPos], sSet[iPos], 0.1, 99999.0);
									g_esPlayer[iPlayer].g_flRewardPercentage[iPos] = flGetClampedValue(key, "RewardPercentage", "Reward Percentage", "Reward_Percentage", "percent", g_esPlayer[iPlayer].g_flRewardPercentage[iPos], sSet[iPos], 0.1, 100.0);
									g_esPlayer[iPlayer].g_flActionDurationReward[iPos] = flGetClampedValue(key, "ActionDurationReward", "Action Duration Reward", "Action_Duration_Reward", "actionduration", g_esPlayer[iPlayer].g_flActionDurationReward[iPos], sSet[iPos], 0.0, 99999.0);
									g_esPlayer[iPlayer].g_flAttackBoostReward[iPos] = flGetClampedValue(key, "AttackBoostReward", "Attack Boost Reward", "Attack_Boost_Reward", "attackboost", g_esPlayer[iPlayer].g_flAttackBoostReward[iPos], sSet[iPos], 0.0, 99999.0);
									g_esPlayer[iPlayer].g_flDamageBoostReward[iPos] = flGetClampedValue(key, "DamageBoostReward", "Damage Boost Reward", "Damage_Boost_Reward", "dmgboost", g_esPlayer[iPlayer].g_flDamageBoostReward[iPos], sSet[iPos], 0.0, 99999.0);
									g_esPlayer[iPlayer].g_flDamageResistanceReward[iPos] = flGetClampedValue(key, "DamageResistanceReward", "Damage Resistance Reward", "Damage_Resistance_Reward", "dmgres", g_esPlayer[iPlayer].g_flDamageResistanceReward[iPos], sSet[iPos], 0.0, 1.0);
									g_esPlayer[iPlayer].g_flHealPercentReward[iPos] = flGetClampedValue(key, "HealPercentReward", "Heal Percent Reward", "Heal_Percent_Reward", "healpercent", g_esPlayer[iPlayer].g_flHealPercentReward[iPos], sSet[iPos], 0.0, 100.0);
									g_esPlayer[iPlayer].g_flJumpHeightReward[iPos] = flGetClampedValue(key, "JumpHeightReward", "Jump Height Reward", "Jump_Height_Reward", "jumpheight", g_esPlayer[iPlayer].g_flJumpHeightReward[iPos], sSet[iPos], 0.0, 99999.0);
									g_esPlayer[iPlayer].g_flLoopingVoicelineInterval[iPos] = flGetClampedValue(key, "LoopingVoicelineInterval", "Looping Voiceline Interval", "Looping_Voiceline_Interval", "loopinterval", g_esPlayer[iPlayer].g_flLoopingVoicelineInterval[iPos], sSet[iPos], 0.1, 99999.0);
									g_esPlayer[iPlayer].g_flPipeBombDurationReward[iPos] = flGetClampedValue(key, "PipebombDurationReward", "Pipebomb Duration Reward", "Pipebomb_Duration_Reward", "pipeduration", g_esPlayer[iPlayer].g_flPipeBombDurationReward[iPos], sSet[iPos], 0.0, 99999.0);
									g_esPlayer[iPlayer].g_flPunchResistanceReward[iPos] = flGetClampedValue(key, "PunchResistanceReward", "Punch Resistance Reward", "Punch_Resistance_Reward", "punchres", g_esPlayer[iPlayer].g_flPunchResistanceReward[iPos], sSet[iPos], 0.0, 1.0);
									g_esPlayer[iPlayer].g_flShoveDamageReward[iPos] = flGetClampedValue(key, "ShoveDamageReward", "Shove Damage Reward", "Shove_Damage_Reward", "shovedmg", g_esPlayer[iPlayer].g_flShoveDamageReward[iPos], sSet[iPos], 0.0, 99999.0);
									g_esPlayer[iPlayer].g_flShoveRateReward[iPos] = flGetClampedValue(key, "ShoveRateReward", "Shove Rate Reward", "Shove_Rate_Reward", "shoverate", g_esPlayer[iPlayer].g_flShoveRateReward[iPos], sSet[iPos], 0.0, 99999.0);
									g_esPlayer[iPlayer].g_flSpeedBoostReward[iPos] = flGetClampedValue(key, "SpeedBoostReward", "Speed Boost Reward", "Speed_Boost_Reward", "speedboost", g_esPlayer[iPlayer].g_flSpeedBoostReward[iPos], sSet[iPos], 0.0, 99999.0);
									g_esPlayer[iPlayer].g_iRewardEnabled[iPos] = iGetClampedValue(key, "RewardEnabled", "Reward Enabled", "Reward_Enabled", "renabled", g_esPlayer[iPlayer].g_iRewardEnabled[iPos], sSet[iPos], -1, 2147483647);
									g_esPlayer[iPlayer].g_iRewardBots[iPos] = iGetClampedValue(key, "RewardBots", "Reward Bots", "Reward_Bots", "bots", g_esPlayer[iPlayer].g_iRewardBots[iPos], sSet[iPos], -1, 2147483647);
									g_esPlayer[iPlayer].g_iRewardEffect[iPos] = iGetClampedValue(key, "RewardEffect", "Reward Effect", "Reward_Effect", "effect", g_esPlayer[iPlayer].g_iRewardEffect[iPos], sSet[iPos], 0, 15);
									g_esPlayer[iPlayer].g_iRewardNotify[iPos] = iGetClampedValue(key, "RewardNotify", "Reward Notify", "Reward_Notify", "rnotify", g_esPlayer[iPlayer].g_iRewardNotify[iPos], sSet[iPos], 0, 3);
									g_esPlayer[iPlayer].g_iRewardVisual[iPos] = iGetClampedValue(key, "RewardVisual", "Reward Visual", "Reward_Visual", "visual", g_esPlayer[iPlayer].g_iRewardVisual[iPos], sSet[iPos], 0, 63);
									g_esPlayer[iPlayer].g_iAmmoBoostReward[iPos] = iGetClampedValue(key, "AmmoBoostReward", "Ammo Boost Reward", "Ammo_Boost_Reward", "ammoboost", g_esPlayer[iPlayer].g_iAmmoBoostReward[iPos], sSet[iPos], 0, 1);
									g_esPlayer[iPlayer].g_iAmmoRegenReward[iPos] = iGetClampedValue(key, "AmmoRegenReward", "Ammo Regen Reward", "Ammo_Regen_Reward", "ammoregen", g_esPlayer[iPlayer].g_iAmmoRegenReward[iPos], sSet[iPos], 0, 99999);
									g_esPlayer[iPlayer].g_iBunnyHopReward[iPos] = iGetClampedValue(key, "BunnyHopReward", "Bunny Hop Reward", "Bunny_Hop_Reward", "bhop", g_esPlayer[iPlayer].g_iBunnyHopReward[iPos], sSet[iPos], 0, 1);
									g_esPlayer[iPlayer].g_iBurstDoorsReward[iPos] = iGetClampedValue(key, "BurstDoorsReward", "Burst Doors Reward", "Burst_Doors_Reward", "burstdoors", g_esPlayer[iPlayer].g_iBurstDoorsReward[iPos], sSet[iPos], 0, 1);
									g_esPlayer[iPlayer].g_iCleanKillsReward[iPos] = iGetClampedValue(key, "CleanKillsReward", "Clean Kills Reward", "Clean_Kills_Reward", "cleankills", g_esPlayer[iPlayer].g_iCleanKillsReward[iPos], sSet[iPos], 0, 1);
									g_esPlayer[iPlayer].g_iFriendlyFireReward[iPos] = iGetClampedValue(key, "FriendlyFireReward", "Friendly Fire Reward", "Friendly_Fire_Reward", "friendlyfire", g_esPlayer[iPlayer].g_iFriendlyFireReward[iPos], sSet[iPos], 0, 1);
									g_esPlayer[iPlayer].g_iHealthRegenReward[iPos] = iGetClampedValue(key, "HealthRegenReward", "Health Regen Reward", "Health_Regen_Reward", "hpregen", g_esPlayer[iPlayer].g_iHealthRegenReward[iPos], sSet[iPos], 0, MT_MAXHEALTH);
									g_esPlayer[iPlayer].g_iHollowpointAmmoReward[iPos] = iGetClampedValue(key, "HollowpointAmmoReward", "Hollowpoint Ammo Reward", "Hollowpoint_Ammo_Reward", "hollowpoint", g_esPlayer[iPlayer].g_iHollowpointAmmoReward[iPos], sSet[iPos], 0, 1);
									g_esPlayer[iPlayer].g_iInextinguishableFireReward[iPos] = iGetClampedValue(key, "InextinguishableFireReward", "Inextinguishable Fire Reward", "Inextinguishable_Fire_Reward", "inexfire", g_esPlayer[iPlayer].g_iInextinguishableFireReward[iPos], sSet[iPos], 0, 1);
									g_esPlayer[iPlayer].g_iInfiniteAmmoReward[iPos] = iGetClampedValue(key, "InfiniteAmmoReward", "Infinite Ammo Reward", "Infinite_Ammo_Reward", "infammo", g_esPlayer[iPlayer].g_iInfiniteAmmoReward[iPos], sSet[iPos], 0, 31);
									g_esPlayer[iPlayer].g_iLadderActionsReward[iPos] = iGetClampedValue(key, "LadderActionsReward", "Ladder Actions Reward", "Ladder_Action_Reward", "ladderactions", g_esPlayer[iPlayer].g_iLadderActionsReward[iPos], sSet[iPos], 0, 1);
									g_esPlayer[iPlayer].g_iLadyKillerReward[iPos] = iGetClampedValue(key, "LadyKillerReward", "Lady Killer Reward", "Lady_Killer_Reward", "ladykiller", g_esPlayer[iPlayer].g_iLadyKillerReward[iPos], sSet[iPos], 0, 1);
									g_esPlayer[iPlayer].g_iLifeLeechReward[iPos] = iGetClampedValue(key, "LifeLeechReward", "Life Leech Reward", "Life_Leech_Reward", "lifeleech", g_esPlayer[iPlayer].g_iLifeLeechReward[iPos], sSet[iPos], 0, MT_MAXHEALTH);
									g_esPlayer[iPlayer].g_iMeleeRangeReward[iPos] = iGetClampedValue(key, "MeleeRangeReward", "Melee Range Reward", "Melee_Range_Reward", "meleerange", g_esPlayer[iPlayer].g_iMeleeRangeReward[iPos], sSet[iPos], 0, 99999);
									g_esPlayer[iPlayer].g_iMidairDashesReward[iPos] = iGetClampedValue(key, "MidairDashesReward", "Midair Dashes Reward", "Midair_Dashes_Reward", "midairdashes", g_esPlayer[iPlayer].g_iMidairDashesReward[iPos], sSet[iPos], 0, 99999);
									g_esPlayer[iPlayer].g_iParticleEffectVisual[iPos] = iGetClampedValue(key, "ParticleEffectVisual", "Particle Effect Visual", "Particle_Effect_Visual", "particle", g_esPlayer[iPlayer].g_iParticleEffectVisual[iPos], sSet[iPos], 0, 15);
									g_esPlayer[iPlayer].g_iPrefsNotify[iPos] = iGetClampedValue(key, "PrefsNotify", "Prefs Notify", "Prefs_Notify", "pnotify", g_esPlayer[iPlayer].g_iPrefsNotify[iPos], sSet[iPos], 0, 1);
									g_esPlayer[iPlayer].g_iRecoilDampenerReward[iPos] = iGetClampedValue(key, "RecoilDampenerReward", "Recoil Dampener Reward", "Recoil_Dampener_Reward", "recoil", g_esPlayer[iPlayer].g_iRecoilDampenerReward[iPos], sSet[iPos], 0, 1);
									g_esPlayer[iPlayer].g_iRespawnLoadoutReward[iPos] = iGetClampedValue(key, "RespawnLoadoutReward", "Respawn Loadout Reward", "Respawn_Loadout_Reward", "resloadout", g_esPlayer[iPlayer].g_iRespawnLoadoutReward[iPos], sSet[iPos], 0, 1);
									g_esPlayer[iPlayer].g_iReviveHealthReward[iPos] = iGetClampedValue(key, "ReviveHealthReward", "Revive Health Reward", "Revive_Health_Reward", "revivehp", g_esPlayer[iPlayer].g_iReviveHealthReward[iPos], sSet[iPos], 0, MT_MAXHEALTH);
									g_esPlayer[iPlayer].g_iShareRewards[iPos] = iGetClampedValue(key, "ShareRewards", "Share Rewards", "Share_Rewards", "share", g_esPlayer[iPlayer].g_iShareRewards[iPos], sSet[iPos], 0, 3);
									g_esPlayer[iPlayer].g_iShovePenaltyReward[iPos] = iGetClampedValue(key, "ShovePenaltyReward", "Shove Penalty Reward", "Shove_Penalty_Reward", "shovepenalty", g_esPlayer[iPlayer].g_iShovePenaltyReward[iPos], sSet[iPos], 0, 1);
									g_esPlayer[iPlayer].g_iSledgehammerRoundsReward[iPos] = iGetClampedValue(key, "SledgehammerRoundsReward", "Sledgehammer Rounds Reward", "Sledgehammer_Rounds_Reward", "sledgehammer", g_esPlayer[iPlayer].g_iSledgehammerRoundsReward[iPos], sSet[iPos], 0, 1);
									g_esPlayer[iPlayer].g_iSpecialAmmoReward[iPos] = iGetClampedValue(key, "SpecialAmmoReward", "Special Ammo Reward", "Special_Ammo_Reward", "specialammo", g_esPlayer[iPlayer].g_iSpecialAmmoReward[iPos], sSet[iPos], 0, 3);
									g_esPlayer[iPlayer].g_iStackRewards[iPos] = iGetClampedValue(key, "StackRewards", "Stack Rewards", "Stack_Rewards", "stack", g_esPlayer[iPlayer].g_iStackRewards[iPos], sSet[iPos], 0, 2147483647);
									g_esPlayer[iPlayer].g_iThornsReward[iPos] = iGetClampedValue(key, "ThornsReward", "Thorns Reward", "Thorns_Reward", "thorns", g_esPlayer[iPlayer].g_iThornsReward[iPos], sSet[iPos], 0, 1);
									g_esPlayer[iPlayer].g_iUsefulRewards[iPos] = iGetClampedValue(key, "UsefulRewards", "Useful Rewards", "Useful_Rewards", "useful", g_esPlayer[iPlayer].g_iUsefulRewards[iPos], sSet[iPos], 0, 15);
									g_esPlayer[iPlayer].g_iVoicePitchVisual[iPos] = iGetClampedValue(key, "VoicePitchVisual", "Voice Pitch Visual", "Voice_Pitch_Visual", "voicepitch", g_esPlayer[iPlayer].g_iVoicePitchVisual[iPos], sSet[iPos], 0, 255);

									vGetConfigColors(sValue, sizeof sValue, sSet[iPos], ';');
									vGetStringValue(key, "BodyColorVisual", "Body Color Visual", "Body_Color_Visual", "bodycolor", iPos, g_esPlayer[iPlayer].g_sBodyColorVisual, sizeof esPlayer::g_sBodyColorVisual, g_esPlayer[iPlayer].g_sBodyColorVisual2, sizeof esPlayer::g_sBodyColorVisual2, g_esPlayer[iPlayer].g_sBodyColorVisual3, sizeof esPlayer::g_sBodyColorVisual3, g_esPlayer[iPlayer].g_sBodyColorVisual4, sizeof esPlayer::g_sBodyColorVisual4, sValue);
									vGetStringValue(key, "FallVoicelineReward", "Fall Voiceline Reward", "Fall_Voiceline_Reward", "fallvoice", iPos, g_esPlayer[iPlayer].g_sFallVoicelineReward, sizeof esPlayer::g_sFallVoicelineReward, g_esPlayer[iPlayer].g_sFallVoicelineReward2, sizeof esPlayer::g_sFallVoicelineReward2, g_esPlayer[iPlayer].g_sFallVoicelineReward3, sizeof esPlayer::g_sFallVoicelineReward3, g_esPlayer[iPlayer].g_sFallVoicelineReward4, sizeof esPlayer::g_sFallVoicelineReward4, sSet[iPos]);
									vGetStringValue(key, "GlowColorVisual", "Glow Color Visual", "Glow_Color_Visual", "glowcolor", iPos, g_esPlayer[iPlayer].g_sOutlineColorVisual, sizeof esPlayer::g_sOutlineColorVisual, g_esPlayer[iPlayer].g_sOutlineColorVisual2, sizeof esPlayer::g_sOutlineColorVisual2, g_esPlayer[iPlayer].g_sOutlineColorVisual3, sizeof esPlayer::g_sOutlineColorVisual3, g_esPlayer[iPlayer].g_sOutlineColorVisual4, sizeof esPlayer::g_sOutlineColorVisual4, sValue);
									vGetStringValue(key, "ItemReward", "Item Reward", "Item_Reward", "item", iPos, g_esPlayer[iPlayer].g_sItemReward, sizeof esPlayer::g_sItemReward, g_esPlayer[iPlayer].g_sItemReward2, sizeof esPlayer::g_sItemReward2, g_esPlayer[iPlayer].g_sItemReward3, sizeof esPlayer::g_sItemReward3, g_esPlayer[iPlayer].g_sItemReward4, sizeof esPlayer::g_sItemReward4, sSet[iPos]);
									vGetStringValue(key, "LightColorVisual", "Light Color Visual", "Light_Color_Visual", "lightcolor", iPos, g_esPlayer[iPlayer].g_sLightColorVisual, sizeof esPlayer::g_sLightColorVisual, g_esPlayer[iPlayer].g_sLightColorVisual2, sizeof esPlayer::g_sLightColorVisual2, g_esPlayer[iPlayer].g_sLightColorVisual3, sizeof esPlayer::g_sLightColorVisual3, g_esPlayer[iPlayer].g_sLightColorVisual4, sizeof esPlayer::g_sLightColorVisual4, sValue);
									vGetStringValue(key, "LoopingVoicelineVisual", "Looping Voiceline Visual", "Looping_Voiceline_Visual", "loopvoice", iPos, g_esPlayer[iPlayer].g_sLoopingVoicelineVisual, sizeof esPlayer::g_sLoopingVoicelineVisual, g_esPlayer[iPlayer].g_sLoopingVoicelineVisual2, sizeof esPlayer::g_sLoopingVoicelineVisual2, g_esPlayer[iPlayer].g_sLoopingVoicelineVisual3, sizeof esPlayer::g_sLoopingVoicelineVisual3, g_esPlayer[iPlayer].g_sLoopingVoicelineVisual4, sizeof esPlayer::g_sLoopingVoicelineVisual4, sSet[iPos]);
									vGetStringValue(key, "ScreenColorVisual", "Screen Color Visual", "Screen_Color_Visual", "screencolor", iPos, g_esPlayer[iPlayer].g_sScreenColorVisual, sizeof esPlayer::g_sScreenColorVisual, g_esPlayer[iPlayer].g_sScreenColorVisual2, sizeof esPlayer::g_sScreenColorVisual2, g_esPlayer[iPlayer].g_sScreenColorVisual3, sizeof esPlayer::g_sScreenColorVisual3, g_esPlayer[iPlayer].g_sScreenColorVisual4, sizeof esPlayer::g_sScreenColorVisual4, sValue);
								}

								g_esPlayer[iPlayer].g_iStackLimits[iPos] = iGetClampedValue(key, "StackLimits", "Stack Limits", "Stack_Limits", "limits", g_esPlayer[iPlayer].g_iStackLimits[iPos], sSet[iPos], 0, 99999);
							}
						}
						else if (StrEqual(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_GLOW, false))
						{
							if (StrEqual(key, "GlowColor", false) || StrEqual(key, "Glow Color", false) || StrEqual(key, "Glow_Color", false))
							{
								char sValue[64], sSet[3][4];
								vGetConfigColors(sValue, sizeof sValue, value);
								strcopy(g_esPlayer[iPlayer].g_sGlowColor, sizeof esPlayer::g_sGlowColor, value);
								ReplaceString(sValue, sizeof sValue, " ", "");
								ExplodeString(sValue, ",", sSet, sizeof sSet, sizeof sSet[]);
								for (int iPos = 0; iPos < (sizeof esPlayer::g_iGlowColor); iPos++)
								{
									g_esPlayer[iPlayer].g_iGlowColor[iPos] = (sSet[iPos][0] != '\0' && StringToInt(sSet[iPos]) >= 0) ? iClamp(StringToInt(sSet[iPos]), 0, 255) : -1;
								}
							}
							else if (StrEqual(key, "GlowRange", false) || StrEqual(key, "Glow Range", false) || StrEqual(key, "Glow_Range", false))
							{
								char sValue[14], sRange[2][7];
								strcopy(sValue, sizeof sValue, value);
								ReplaceString(sValue, sizeof sValue, " ", "");
								ExplodeString(sValue, "-", sRange, sizeof sRange, sizeof sRange[]);

								g_esPlayer[iPlayer].g_iGlowMinRange = (sRange[0][0] != '\0') ? iClamp(StringToInt(sRange[0]), 0, 99999) : g_esPlayer[iPlayer].g_iGlowMinRange;
								g_esPlayer[iPlayer].g_iGlowMaxRange = (sRange[1][0] != '\0') ? iClamp(StringToInt(sRange[1]), 0, 99999) : g_esPlayer[iPlayer].g_iGlowMaxRange;
							}
						}
						else if (StrEqual(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_BOSS, false))
						{
							char sValue[44], sSet[4][11];
							strcopy(sValue, sizeof sValue, value);
							ReplaceString(sValue, sizeof sValue, " ", "");
							ExplodeString(sValue, ",", sSet, sizeof sSet, sizeof sSet[]);
							for (int iPos = 0; iPos < (sizeof esPlayer::g_iBossHealth); iPos++)
							{
								g_esPlayer[iPlayer].g_iBossHealth[iPos] = iGetClampedValue(key, "BossHealthStages", "Boss Health Stages", "Boss_Health_Stages", "bosshpstages", g_esPlayer[iPlayer].g_iBossHealth[iPos], sSet[iPos], 1, MT_MAXHEALTH);
								g_esPlayer[iPlayer].g_iBossType[iPos] = iGetClampedValue(key, "BossTypes", "Boss Types", "Boss_Types", "bosstypes", g_esPlayer[iPlayer].g_iBossType[iPos], sSet[iPos], 1, MT_MAXTYPES);
							}
						}
						else if (StrEqual(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_COMBO, false))
						{
							if (StrEqual(key, "ComboTypeChance", false) || StrEqual(key, "Combo Type Chance", false) || StrEqual(key, "Combo_Type_Chance", false) || StrEqual(key, "typechance", false))
							{
								char sValue[42], sSet[7][6];
								strcopy(sValue, sizeof sValue, value);
								ReplaceString(sValue, sizeof sValue, " ", "");
								ExplodeString(sValue, ",", sSet, sizeof sSet, sizeof sSet[]);
								for (int iPos = 0; iPos < (sizeof esPlayer::g_flComboTypeChance); iPos++)
								{
									g_esPlayer[iPlayer].g_flComboTypeChance[iPos] = (sSet[iPos][0] != '\0') ? flClamp(StringToFloat(sSet[iPos]), 0.0, 100.0) : g_esPlayer[iPlayer].g_flComboTypeChance[iPos];
								}
							}
							else
							{
								char sValue[140], sSet[10][14];
								strcopy(sValue, sizeof sValue, value);
								ReplaceString(sValue, sizeof sValue, " ", "");
								ExplodeString(sValue, ",", sSet, sizeof sSet, sizeof sSet[]);
								for (int iPos = 0; iPos < (sizeof esPlayer::g_flComboChance); iPos++)
								{
									if (StrEqual(key, "ComboRadius", false) || StrEqual(key, "Combo Radius", false) || StrEqual(key, "Combo_Radius", false) || StrEqual(key, "radius", false))
									{
										char sRange[2][7], sSubset[14];
										strcopy(sSubset, sizeof sSubset, sSet[iPos]);
										ReplaceString(sSubset, sizeof sSubset, " ", "");
										ExplodeString(sSubset, ";", sRange, sizeof sRange, sizeof sRange[]);

										g_esPlayer[iPlayer].g_flComboMinRadius[iPos] = (sRange[0][0] != '\0') ? flClamp(StringToFloat(sRange[0]), -200.0, 0.0) : g_esPlayer[iPlayer].g_flComboMinRadius[iPos];
										g_esPlayer[iPlayer].g_flComboMaxRadius[iPos] = (sRange[1][0] != '\0') ? flClamp(StringToFloat(sRange[1]), 0.0, 200.0) : g_esPlayer[iPlayer].g_flComboMaxRadius[iPos];
									}
									else
									{
										g_esPlayer[iPlayer].g_flComboChance[iPos] = flGetClampedValue(key, "ComboChance", "Combo Chance", "Combo_Chance", "chance", g_esPlayer[iPlayer].g_flComboChance[iPos], sSet[iPos], 0.0, 100.0);
										g_esPlayer[iPlayer].g_iComboCooldown[iPos] = iGetClampedValue(key, "ComboCooldown", "Combo Cooldown", "Combo_Cooldown", "cooldown", g_esPlayer[iPlayer].g_iComboCooldown[iPos], sSet[iPos], 0, 99999);
										g_esPlayer[iPlayer].g_flComboDamage[iPos] = flGetClampedValue(key, "ComboDamage", "Combo Damage", "Combo_Damage", "damage", g_esPlayer[iPlayer].g_flComboDamage[iPos], sSet[iPos], 0.0, 99999.0);
										g_esPlayer[iPlayer].g_flComboDeathChance[iPos] = flGetClampedValue(key, "ComboDeathChance", "Combo Death Chance", "Combo_Death_Chance", "deathchance", g_esPlayer[iPlayer].g_flComboDeathChance[iPos], sSet[iPos], 0.0, 100.0);
										g_esPlayer[iPlayer].g_flComboDeathRange[iPos] = flGetClampedValue(key, "ComboDeathRange", "Combo Death Range", "Combo_Death_Range", "deathrange", g_esPlayer[iPlayer].g_flComboDeathRange[iPos], sSet[iPos], 0.0, 99999.0);
										g_esPlayer[iPlayer].g_flComboDelay[iPos] = flGetClampedValue(key, "ComboDelay", "Combo Delay", "Combo_Delay", "delay", g_esPlayer[iPlayer].g_flComboDelay[iPos], sSet[iPos], 0.0, 99999.0);
										g_esPlayer[iPlayer].g_flComboDuration[iPos] = flGetClampedValue(key, "ComboDuration", "Combo Duration", "Combo_Duration", "duration", g_esPlayer[iPlayer].g_flComboDuration[iPos], sSet[iPos], 0.0, 99999.0);
										g_esPlayer[iPlayer].g_flComboInterval[iPos] = flGetClampedValue(key, "ComboInterval", "Combo Interval", "Combo_Interval", "interval", g_esPlayer[iPlayer].g_flComboInterval[iPos], sSet[iPos], 0.0, 99999.0);
										g_esPlayer[iPlayer].g_flComboRange[iPos] = flGetClampedValue(key, "ComboRange", "Combo Range", "Combo_Range", "range", g_esPlayer[iPlayer].g_flComboRange[iPos], sSet[iPos], 0.0, 99999.0);
										g_esPlayer[iPlayer].g_flComboRangeChance[iPos] = flGetClampedValue(key, "ComboRangeChance", "Combo Range Chance", "Combo_Range_Chance", "rangechance", g_esPlayer[iPlayer].g_flComboRangeChance[iPos], sSet[iPos], 0.0, 100.0);
										g_esPlayer[iPlayer].g_iComboRangeCooldown[iPos] = iGetClampedValue(key, "ComboRangeCooldown", "Combo Range Cooldown", "Combo_Range_Cooldown", "rangecooldown", g_esPlayer[iPlayer].g_iComboRangeCooldown[iPos], sSet[iPos], 0, 99999);
										g_esPlayer[iPlayer].g_flComboRockChance[iPos] = flGetClampedValue(key, "ComboRockChance", "Combo Rock Chance", "Combo_Rock_Chance", "rockchance", g_esPlayer[iPlayer].g_flComboRockChance[iPos], sSet[iPos], 0.0, 100.0);
										g_esPlayer[iPlayer].g_iComboRockCooldown[iPos] = iGetClampedValue(key, "ComboRockCooldown", "Combo Rock Cooldown", "Combo_Rock_Cooldown", "rockcooldown", g_esPlayer[iPlayer].g_iComboRockCooldown[iPos], sSet[iPos], 0, 99999);
										g_esPlayer[iPlayer].g_flComboSpeed[iPos] = flGetClampedValue(key, "ComboSpeed", "Combo Speed", "Combo_Speed", "speed", g_esPlayer[iPlayer].g_flComboSpeed[iPos], sSet[iPos], 0.0, 99999.0);
									}
								}
							}
						}
						else if (StrEqual(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_TRANSFORM, false))
						{
							if (StrEqual(key, "TransformTypes", false) || StrEqual(key, "Transform Types", false) || StrEqual(key, "Transform_Types", false) || StrEqual(key, "transtypes", false))
							{
								char sValue[50], sSet[10][5];
								strcopy(sValue, sizeof sValue, value);
								ReplaceString(sValue, sizeof sValue, " ", "");
								ExplodeString(sValue, ",", sSet, sizeof sSet, sizeof sSet[]);
								for (int iPos = 0; iPos < (sizeof esPlayer::g_iTransformType); iPos++)
								{
									g_esPlayer[iPlayer].g_iTransformType[iPos] = (sSet[iPos][0] != '\0') ? iClamp(StringToInt(sSet[iPos]), 1, MT_MAXTYPES) : g_esPlayer[iPlayer].g_iTransformType[iPos];
								}
							}
						}
						else if (StrEqual(g_esGeneral.g_sCurrentSubSection, MT_CONFIG_SECTION_PROPS, false))
						{
							if (StrEqual(key, "PropsChance", false) || StrEqual(key, "Props Chance", false) || StrEqual(key, "Props_Chance", false) || StrEqual(key, "chance", false))
							{
								char sValue[54], sSet[9][6];
								strcopy(sValue, sizeof sValue, value);
								ReplaceString(sValue, sizeof sValue, " ", "");
								ExplodeString(sValue, ",", sSet, sizeof sSet, sizeof sSet[]);
								for (int iPos = 0; iPos < (sizeof esPlayer::g_flPropsChance); iPos++)
								{
									g_esPlayer[iPlayer].g_flPropsChance[iPos] = (sSet[iPos][0] != '\0') ? flClamp(StringToFloat(sSet[iPos]), 0.0, 100.0) : g_esPlayer[iPlayer].g_flPropsChance[iPos];
								}
							}
							else
							{
								char sValue[64], sSet[4][4];
								vGetConfigColors(sValue, sizeof sValue, value);
								vSaveConfigColors(key, "OxygenTankColor", "Oxygen Tank Color", "Oxygen_Tank_Color", "oxygen", g_esPlayer[iPlayer].g_sOzTankColor, sizeof esPlayer::g_sOzTankColor, value);
								vSaveConfigColors(key, "FlameColor", "Flame Color", "Flame_Color", "flame", g_esPlayer[iPlayer].g_sFlameColor, sizeof esPlayer::g_sFlameColor, value);
								vSaveConfigColors(key, "RockColor", "Rock Color", "Rock_Color", "rock", g_esPlayer[iPlayer].g_sRockColor, sizeof esPlayer::g_sRockColor, value);
								vSaveConfigColors(key, "TireColor", "Tire Color", "Tire_Color", "tire", g_esPlayer[iPlayer].g_sTireColor, sizeof esPlayer::g_sTireColor, value);
								vSaveConfigColors(key, "PropaneTankColor", "Propane Tank Color", "Propane_Tank_Color", "propane", g_esPlayer[iPlayer].g_sPropTankColor, sizeof esPlayer::g_sPropTankColor, value);
								vSaveConfigColors(key, "FlashlightColor", "Flashlight Color", "Flashlight_Color", "flashlight", g_esPlayer[iPlayer].g_sFlashlightColor, sizeof esPlayer::g_sFlashlightColor, value);
								ReplaceString(sValue, sizeof sValue, " ", "");
								ExplodeString(sValue, ",", sSet, sizeof sSet, sizeof sSet[]);

								for (int iPos = 0; iPos < (sizeof esPlayer::g_iLightColor); iPos++)
								{
									g_esPlayer[iPlayer].g_iLightColor[iPos] = iGetClampedValue(key, "LightColor", "Light Color", "Light_Color", "light", g_esPlayer[iPlayer].g_iLightColor[iPos], sSet[iPos], 0, 255, 0);
									g_esPlayer[iPlayer].g_iOzTankColor[iPos] = iGetClampedValue(key, "OxygenTankColor", "Oxygen Tank Color", "Oxygen_Tank_Color", "oxygen", g_esPlayer[iPlayer].g_iOzTankColor[iPos], sSet[iPos], 0, 255, 0);
									g_esPlayer[iPlayer].g_iFlameColor[iPos] = iGetClampedValue(key, "FlameColor", "Flame Color", "Flame_Color", "flame", g_esPlayer[iPlayer].g_iFlameColor[iPos], sSet[iPos], 0, 255, 0);
									g_esPlayer[iPlayer].g_iRockColor[iPos] = iGetClampedValue(key, "RockColor", "Rock Color", "Rock_Color", "rock", g_esPlayer[iPlayer].g_iRockColor[iPos], sSet[iPos], 0, 255, 0);
									g_esPlayer[iPlayer].g_iTireColor[iPos] = iGetClampedValue(key, "TireColor", "Tire Color", "Tire_Color", "tire", g_esPlayer[iPlayer].g_iTireColor[iPos], sSet[iPos], 0, 255, 0);
									g_esPlayer[iPlayer].g_iPropTankColor[iPos] = iGetClampedValue(key, "PropaneTankColor", "Propane Tank Color", "Propane_Tank_Color", "propane", g_esPlayer[iPlayer].g_iPropTankColor[iPos], sSet[iPos], 0, 255, 0);
									g_esPlayer[iPlayer].g_iFlashlightColor[iPos] = iGetClampedValue(key, "FlashlightColor", "Flashlight Color", "Flashlight_Color", "flashlight", g_esPlayer[iPlayer].g_iFlashlightColor[iPos], sSet[iPos], 0, 255, 0);
									g_esPlayer[iPlayer].g_iCrownColor[iPos] = iGetClampedValue(key, "CrownColor", "Crown Color", "Crown_Color", "crown", g_esPlayer[iPlayer].g_iCrownColor[iPos], sSet[iPos], 0, 255, 0);
								}
							}
						}
						else if (!strncmp(g_esGeneral.g_sCurrentSubSection, "Tank", 4, false) || g_esGeneral.g_sCurrentSubSection[0] == '#' || IsCharNumeric(g_esGeneral.g_sCurrentSubSection[0]) || StrContains(g_esGeneral.g_sCurrentSubSection, "all", false) != -1 || FindCharInString(g_esGeneral.g_sCurrentSubSection, ',') != -1 || FindCharInString(g_esGeneral.g_sCurrentSubSection, '-') != -1)
						{
							if (!strncmp(g_esGeneral.g_sCurrentSubSection, "Tank", 4, false) || g_esGeneral.g_sCurrentSubSection[0] == '#')
							{
								vReadAdminSettings(iPlayer, key, value);
							}
							else if (IsCharNumeric(g_esGeneral.g_sCurrentSubSection[0]) || StrContains(g_esGeneral.g_sCurrentSubSection, "all", false) != -1 || FindCharInString(g_esGeneral.g_sCurrentSubSection, ',') != -1 || FindCharInString(g_esGeneral.g_sCurrentSubSection, '-') != -1)
							{
								if (IsCharNumeric(g_esGeneral.g_sCurrentSubSection[0]) && FindCharInString(g_esGeneral.g_sCurrentSubSection, ',') == -1 && FindCharInString(g_esGeneral.g_sCurrentSubSection, '-') == -1)
								{
									vReadAdminSettings(iPlayer, key, value);
								}
								else if (StrContains(g_esGeneral.g_sCurrentSubSection, "all", false) != -1 || FindCharInString(g_esGeneral.g_sCurrentSubSection, ',') != -1 || FindCharInString(g_esGeneral.g_sCurrentSubSection, '-') != -1)
								{
									int iRealType = 0;
									for (int iIndex = g_esGeneral.g_iMinType; iIndex <= g_esGeneral.g_iMaxType; iIndex++)
									{
										if (iIndex <= 0)
										{
											continue;
										}

										iRealType = iFindSectionType(g_esGeneral.g_sCurrentSubSection, iIndex);
										if (iIndex == g_esTank[iRealType].g_iRecordedType[1] || StrContains(g_esGeneral.g_sCurrentSubSection, "all", false) != -1)
										{
											vReadAdminSettings(iPlayer, key, value);
										}
									}
								}
							}
						}

						vConfigsLoadedForward(g_esGeneral.g_sCurrentSubSection, key, value, 0, iPlayer, g_esGeneral.g_iConfigMode);

						break;
					}
				}
			}
		}
	}

	return SMCParse_Continue;
}

SMCResult SMCEndSection_Main(SMCParser smc)
{
	if (g_esGeneral.g_iIgnoreLevel)
	{
		g_esGeneral.g_iIgnoreLevel--;

		return SMCParse_Continue;
	}

	if (g_esGeneral.g_csState == ConfigState_Specific)
	{
		if (StrEqual(g_esGeneral.g_sCurrentSection, MT_CONFIG_SECTION_SETTINGS, false) || StrEqual(g_esGeneral.g_sCurrentSection, MT_CONFIG_SECTION_SETTINGS2, false) || StrEqual(g_esGeneral.g_sCurrentSection, MT_CONFIG_SECTION_SETTINGS3, false) || StrEqual(g_esGeneral.g_sCurrentSection, MT_CONFIG_SECTION_SETTINGS4, false))
		{
			g_esGeneral.g_csState = ConfigState_Settings;
		}
		else if (!strncmp(g_esGeneral.g_sCurrentSection, "Tank", 4, false) || g_esGeneral.g_sCurrentSection[0] == '#' || IsCharNumeric(g_esGeneral.g_sCurrentSection[0]) || StrContains(g_esGeneral.g_sCurrentSection, "all", false) != -1 || FindCharInString(g_esGeneral.g_sCurrentSection, ',') != -1 || FindCharInString(g_esGeneral.g_sCurrentSection, '-') != -1)
		{
			g_esGeneral.g_csState = ConfigState_Type;
		}
		else if (!strncmp(g_esGeneral.g_sCurrentSection, "STEAM_", 6, false) || !strncmp("0:", g_esGeneral.g_sCurrentSection, 2) || !strncmp("1:", g_esGeneral.g_sCurrentSection, 2) || (!strncmp(g_esGeneral.g_sCurrentSection, "[U:", 3) && g_esGeneral.g_sCurrentSection[strlen(g_esGeneral.g_sCurrentSection) - 1] == ']'))
		{
			g_esGeneral.g_csState = ConfigState_Admin;
		}
	}
	else if (g_esGeneral.g_csState == ConfigState_Settings || g_esGeneral.g_csState == ConfigState_Type || g_esGeneral.g_csState == ConfigState_Admin)
	{
		g_esGeneral.g_csState = ConfigState_Start;
	}
	else if (g_esGeneral.g_csState == ConfigState_Start)
	{
		g_esGeneral.g_csState = ConfigState_None;
	}

	return SMCParse_Continue;
}

SMCResult SMCRawLine_Main(SMCParser smc, const char[] line, int lineno)
{
	g_esGeneral.g_iCurrentLine = lineno;

	return SMCParse_Continue;
}

void SMCParseEnd_Main(SMCParser smc, bool halted, bool failed)
{
	g_esGeneral.g_csState = ConfigState_None;
	g_esGeneral.g_iIgnoreLevel = 0;
	g_esGeneral.g_iTypeCounter[0] = 0;
	g_esGeneral.g_iTypeCounter[1] = 0;
	g_esGeneral.g_sCurrentSection[0] = '\0';
	g_esGeneral.g_sCurrentSubSection[0] = '\0';

	vClearAbilityList();

	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer))
		{
			vCacheSettings(iPlayer);
		}
	}
}

/**
 * Logging functions
 **/

void vLogCommand(int admin, int type, const char[] activity, any ...)
{
	if (g_esGeneral.g_iLogCommands & type)
	{
		char sMessage[PLATFORM_MAX_PATH];
		for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
		{
			if (bIsValidClient(iPlayer, MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) && CheckCommandAccess(iPlayer, "sm_admin", ADMFLAG_ROOT, true) && iPlayer != admin)
			{
				SetGlobalTransTarget(iPlayer);
				VFormat(sMessage, sizeof sMessage, activity, 4);
				MT_PrintToChat(iPlayer, sMessage);
			}
		}
	}
}

void vLogMessage(int type, bool timestamp = true, const char[] message, any ...)
{
	if (type == -1 || (g_esGeneral.g_iLogMessages & type))
	{
		Action aResult = Plugin_Continue;
		Call_StartForward(g_esGeneral.g_gfLogMessageForward);
		Call_PushCell(type);
		Call_PushString(message);
		Call_Finish(aResult);

		switch (aResult)
		{
			case Plugin_Handled: return;
			case Plugin_Continue:
			{
				char sBuffer[2048], sMessage[2048];
				SetGlobalTransTarget(LANG_SERVER);
				strcopy(sMessage, sizeof sMessage, message);
				VFormat(sBuffer, sizeof sBuffer, sMessage, 4);
				MT_ReplaceChatPlaceholders(sBuffer, sizeof sBuffer, true);

				switch (timestamp)
				{
					case true:
					{
						char sTime[32];
						FormatTime(sTime, sizeof sTime, "%Y-%m-%d - %H:%M:%S", GetTime());
						FormatEx(sMessage, sizeof sMessage, "[%s] %s", sTime, sBuffer);
						vSaveMessage(sMessage);
					}
					case false: vSaveMessage(sBuffer);
				}

				PrintToServer(sBuffer);
			}
		}
	}
}

void vSaveMessage(const char[] message)
{
	File fLog = OpenFile(g_esGeneral.g_sLogFile, "a");
	if (fLog != null)
	{
		fLog.WriteLine(message);

		delete fLog;
	}
}

void vToggleLogging(int type = -1)
{
	char sMessage[PLATFORM_MAX_PATH], sMap[128], sTime[32], sDate[32];
	GetCurrentMap(sMap, sizeof sMap);
	FormatTime(sTime, sizeof sTime, "%m/%d/%Y %H:%M:%S", GetTime());
	FormatTime(sDate, sizeof sDate, "%Y-%m-%d", GetTime());
	BuildPath(Path_SM, g_esGeneral.g_sLogFile, sizeof esGeneral::g_sLogFile, "logs/mutant_tanks_%s.log", sDate);

	bool bLog = false;
	int iType = 0;

	switch (type)
	{
		case -1:
		{
			if (g_esGeneral.g_iLogMessages != iType)
			{
				bLog = true;
				iType = g_esGeneral.g_iLogMessages;

				FormatEx(sMessage, sizeof sMessage, "%T", ((iType != 0) ? "LogStarted" : "LogEnded"), LANG_SERVER, sTime, sMap);
			}
		}
		case 0, 1:
		{
			if (g_esGeneral.g_iLogMessages != 0)
			{
				bLog = true;
				iType = g_esGeneral.g_iLogMessages;

				FormatEx(sMessage, sizeof sMessage, "%T", ((type == 1) ? "LogStarted" : "LogEnded"), LANG_SERVER, sTime, sMap);
			}
		}
	}

	if (bLog)
	{
		int iLength = strlen(sMessage), iSize = (iLength + 1);
		char[] sBorder = new char[iSize];
		StrCat(sBorder, iLength, "--");
		for (int iPos = 0; iPos < (iLength - 4); iPos++)
		{
			StrCat(sBorder, iSize, "=");
		}

		StrCat(sBorder, iSize, "--");
		vSaveMessage(sBorder);
		vSaveMessage(sMessage);
		vSaveMessage(sBorder);
	}
}

/**
 * RequestFrame callbacks
 **/

void vDetonateRockFrame(int ref)
{
	int iRock = EntRefToEntIndex(ref);
	if (bIsValidEntity(iRock) && g_esGeneral.g_hSDKRockDetonate != null)
	{
		SDKCall(g_esGeneral.g_hSDKRockDetonate, iRock);
	}
}

void vInfectedTransmitFrame(int ref)
{
	int iCommon = EntRefToEntIndex(ref);
	if (bIsValidEntity(iCommon))
	{
		SDKHook(iCommon, SDKHook_SetTransmit, OnInfectedSetTransmit);
	}
}

void vPlayerSpawnFrame(DataPack pack)
{
	pack.Reset();
	int iPlayer = GetClientOfUserId(pack.ReadCell()), iType = pack.ReadCell();
	delete pack;

	if (bIsSurvivor(iPlayer))
	{
		if (!g_esPlayer[iPlayer].g_bSetup)
		{
			g_esPlayer[iPlayer].g_bSetup = true;

			if (bIsDeveloper(iPlayer))
			{
				vSetupDeveloper(iPlayer, .usual = true);
			}
		}

		if (!bIsDeveloper(iPlayer, 0))
		{
			char sDelimiter[2];
			float flTime = GetGameTime();
			if (g_esPlayer[iPlayer].g_flVisualTime[4] != -1.0 && g_esPlayer[iPlayer].g_flVisualTime[4] > flTime)
			{
				sDelimiter = (FindCharInString(g_esPlayer[iPlayer].g_sLightColor, ';') != -1) ? ";" : ",";
				vSetSurvivorLight(iPlayer, g_esPlayer[iPlayer].g_sLightColor, g_esPlayer[iPlayer].g_bApplyVisuals[4], sDelimiter, true);
			}

			if (g_esPlayer[iPlayer].g_flVisualTime[5] != -1.0 && g_esPlayer[iPlayer].g_flVisualTime[5] > flTime)
			{
				sDelimiter = (FindCharInString(g_esPlayer[iPlayer].g_sBodyColor, ';') != -1) ? ";" : ",";
				vSetSurvivorColor(iPlayer, g_esPlayer[iPlayer].g_sBodyColor, g_esPlayer[iPlayer].g_bApplyVisuals[5], sDelimiter, true);
			}

			if (g_esPlayer[iPlayer].g_flVisualTime[6] != -1.0 && g_esPlayer[iPlayer].g_flVisualTime[6] > flTime)
			{
				sDelimiter = (FindCharInString(g_esPlayer[iPlayer].g_sOutlineColor, ';') != -1) ? ";" : ",";
				vSetSurvivorOutline(iPlayer, g_esPlayer[iPlayer].g_sOutlineColor, g_esPlayer[iPlayer].g_bApplyVisuals[6], sDelimiter, true);
			}
		}
		else if (g_esDeveloper[iPlayer].g_iDevAccess == 1)
		{
			vSetupPerks(iPlayer);
		}

		vRefillGunAmmo(iPlayer, .reset = true);
	}
	else if (bIsTank(iPlayer) && !g_esPlayer[iPlayer].g_bFirstSpawn)
	{
		if (g_bSecondGame)
		{
			g_esPlayer[iPlayer].g_bStasis = (bIsTankInStasis(iPlayer) || (g_esGeneral.g_hSDKIsInStasis != null && SDKCall(g_esGeneral.g_hSDKIsInStasis, iPlayer)));
		}

		if (g_esPlayer[iPlayer].g_bStasis && g_esGeneral.g_iStasisMode == 1 && g_esGeneral.g_hSDKLeaveStasis != null)
		{
			SDKCall(g_esGeneral.g_hSDKLeaveStasis, iPlayer);
		}

		g_esPlayer[iPlayer].g_bFirstSpawn = true;

		if (g_esPlayer[iPlayer].g_bDied)
		{
			g_esPlayer[iPlayer].g_bDied = false;
			g_esPlayer[iPlayer].g_iOldTankType = 0;
			g_esPlayer[iPlayer].g_iTankType = 0;
		}

		if (g_esGeneral.g_flIdleCheck > 0.0)
		{
			CreateTimer(g_esGeneral.g_flIdleCheck, tTimerKillIdleTank, GetClientUserId(iPlayer), TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
		}

		if (g_esGeneral.g_bForceSpawned)
		{
			g_esPlayer[iPlayer].g_bArtificial = true;
		}

		switch (iType)
		{
			case 0:
			{
				switch (bIsTank(iPlayer, MT_CHECK_FAKECLIENT))
				{
					case true:
					{
						if (g_esGeneral.g_iSpawnMode != 2)
						{
							vTankMenu(iPlayer);
						}

						if (g_esGeneral.g_iSpawnMode != 0 && g_esGeneral.g_iSpawnMode != 3)
						{
							vMutateTank(iPlayer, iType);
						}
					}
					case false: vMutateTank(iPlayer, iType);
				}
			}
			default: vMutateTank(iPlayer, iType);
		}
	}
}

void vRespawnFrame(int userid)
{
	int iSurvivor = GetClientOfUserId(userid);
	if (g_esGeneral.g_bPluginEnabled && bIsSurvivor(iSurvivor, MT_CHECK_INDEX|MT_CHECK_INGAME) && bIsDeveloper(iSurvivor, 10))
	{
		bRespawnSurvivor(iSurvivor, true);
	}
}

void vRockThrowFrame(int ref)
{
	int iRock = EntRefToEntIndex(ref);
	if (g_esGeneral.g_bPluginEnabled && bIsValidEntity(iRock))
	{
		int iThrower = GetEntPropEnt(iRock, Prop_Data, "m_hThrower");
		if (bIsTankSupported(iThrower) && bHasCoreAdminAccess(iThrower) && !bIsTankIdle(iThrower) && g_esCache[iThrower].g_iTankEnabled == 1)
		{
			switch (StrEqual(g_esCache[iThrower].g_sRockColor, "rainbow", false))
			{
				case true:
				{
					g_esPlayer[iThrower].g_iThrownRock[iRock] = ref;

					if (!g_esPlayer[iThrower].g_bRainbowColor)
					{
						g_esPlayer[iThrower].g_bRainbowColor = SDKHookEx(iThrower, SDKHook_PreThinkPost, OnRainbowPreThinkPost);
					}
				}
				case false: SetEntityRenderColor(iRock, iGetRandomColor(g_esCache[iThrower].g_iRockColor[0]), iGetRandomColor(g_esCache[iThrower].g_iRockColor[1]), iGetRandomColor(g_esCache[iThrower].g_iRockColor[2]), iGetRandomColor(g_esCache[iThrower].g_iRockColor[3]));
			}

			vSetRockModel(iThrower, iRock);

			if (g_esCache[iThrower].g_iRockEffects > 0)
			{
				DataPack dpRockEffects;
				CreateDataTimer(0.75, tTimerRockEffects, dpRockEffects, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
				dpRockEffects.WriteCell(ref);
				dpRockEffects.WriteCell(GetClientUserId(iThrower));
			}

			Call_StartForward(g_esGeneral.g_gfRockThrowForward);
			Call_PushCell(iThrower);
			Call_PushCell(iRock);
			Call_Finish();

			vCombineAbilitiesForward(iThrower, MT_COMBO_ROCKTHROW, .weapon = iRock);
		}
	}
}

void vTankSpawnFrame(DataPack pack)
{
	pack.Reset();
	int iTank = GetClientOfUserId(pack.ReadCell()), iMode = pack.ReadCell();
	delete pack;

	if (bIsTankSupported(iTank) && bHasCoreAdminAccess(iTank))
	{
		vCacheSettings(iTank);

		if (!bIsInfectedGhost(iTank) && !g_esPlayer[iTank].g_bStasis)
		{
			float flCurrentTime = GetGameTime();
			g_esPlayer[iTank].g_bKeepCurrentType = false;
			g_esPlayer[iTank].g_flLastAttackTime = flCurrentTime;
			g_esPlayer[iTank].g_flLastThrowTime = flCurrentTime;

			char sOldName[33], sNewName[33];
			vGetTranslatedName(sOldName, sizeof sOldName, .type = g_esPlayer[iTank].g_iOldTankType);
			vGetTranslatedName(sNewName, sizeof sNewName, .type = g_esPlayer[iTank].g_iTankType);
			vSetTankName(iTank, sOldName, sNewName, iMode);

			vParticleEffects(iTank);
			vResetTankSpeed(iTank, false);
			vSetTankProps(iTank);

			SDKHook(iTank, SDKHook_PostThinkPost, OnTankPostThinkPost);

			Call_StartForward(g_esGeneral.g_gfPostTankSpawnForward);
			Call_PushCell(iTank);
			Call_Finish();

			vCombineAbilitiesForward(iTank, MT_COMBO_POSTSPAWN);
		}

		switch (iMode)
		{
			case -1:
			{
				vSetTankRainbowColor(iTank);
				vSpawnMessages(iTank);
			}
			case 0:
			{
				if (!bIsCustomTank(iTank) && !bIsInfectedGhost(iTank))
				{
					vSetTankHealth(iTank);
					vSpawnMessages(iTank);

					g_esGeneral.g_iTankCount++;
				}

				g_esPlayer[iTank].g_iTankHealth = GetEntProp(iTank, Prop_Data, "m_iMaxHealth");
			}
			case 5: vSetTankHealth(iTank, false);
		}
	}
}

void vWeaponSkinFrame(int userid)
{
	int iSurvivor = GetClientOfUserId(userid);
	if (bIsSurvivor(iSurvivor) && bIsDeveloper(iSurvivor, 2))
	{
		vSetSurvivorWeaponSkin(iSurvivor);
	}
}

/**
 * SDHooks & SDKTools callbacks
 **/

// OnTakeDamage hooks

Action OnCombineTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (g_esGeneral.g_bPluginEnabled && bIsValidClient(victim) && damage > 0.0)
	{
		char sClassname[32];
		GetEntityClassname(inflictor, sClassname, sizeof sClassname);
		if (bIsTankSupported(attacker) && bIsSurvivor(victim))
		{
			if (!bHasCoreAdminAccess(attacker) || bIsCoreAdminImmune(victim, attacker))
			{
				return Plugin_Continue;
			}

			if (StrEqual(sClassname[7], "tank_claw") || StrEqual(sClassname, "tank_rock"))
			{
				vCombineAbilitiesForward(attacker, MT_COMBO_MELEEHIT, victim, .classname = sClassname);
			}
		}
		else if (bIsTankSupported(victim) && bIsSurvivor(attacker))
		{
			if (!bHasCoreAdminAccess(victim) || bIsCoreAdminImmune(attacker, victim))
			{
				return Plugin_Continue;
			}

			if (StrEqual(sClassname[7], "melee"))
			{
				vCombineAbilitiesForward(victim, MT_COMBO_MELEEHIT, attacker, .classname = sClassname);
			}
		}
	}

	return Plugin_Continue;
}

Action OnFriendlyTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (g_esGeneral.g_bPluginEnabled && damage > 0.0)
	{
		if (bIsSurvivor(victim) && bIsSurvivor(attacker))
		{
			if ((bIsDeveloper(victim, 4) || ((g_esPlayer[victim].g_iRewardTypes & MT_REWARD_DAMAGEBOOST) && g_esPlayer[victim].g_iFriendlyFire == 1)) || (bIsDeveloper(attacker, 4) || ((g_esPlayer[attacker].g_iRewardTypes & MT_REWARD_DAMAGEBOOST) && g_esPlayer[attacker].g_iFriendlyFire == 1)))
			{
				return Plugin_Handled;
			}
		}
		else if (bIsValidClient(attacker, MT_CHECK_INDEX) && bIsValidEntity(inflictor) && (g_esGeneral.g_iTeamID2[inflictor] == 2 || damagetype == 134217792))
		{
			if ((bIsDeveloper(victim, 4) || ((g_esPlayer[victim].g_iRewardTypes & MT_REWARD_DAMAGEBOOST) && g_esPlayer[victim].g_iFriendlyFire == 1)) && GetClientTeam(victim) == 2 && GetClientTeam(attacker) != 2)
			{
				if (damagetype == 134217792)
				{
					char sClassname[5];
					GetEntityClassname(inflictor, sClassname, sizeof sClassname);
					if (StrEqual(sClassname, "pipe"))
					{
						return Plugin_Handled;
					}
				}

				return Plugin_Handled;
			}
		}
		else if (attacker == inflictor && bIsValidEntity(inflictor) && (g_esGeneral.g_iTeamID2[inflictor] == 2 || damagetype == 134217792) && GetClientTeam(victim) == 2)
		{
			if (damagetype == 134217792)
			{
				char sClassname[5];
				GetEntityClassname(inflictor, sClassname, sizeof(sClassname));
				if (StrEqual(sClassname, "pipe") && (bIsDeveloper(victim, 4) || ((g_esPlayer[victim].g_iRewardTypes & MT_REWARD_DAMAGEBOOST) && g_esPlayer[victim].g_iFriendlyFire == 1)))
				{
					return Plugin_Handled;
				}
			}
			else
			{
				attacker = GetEntPropEnt(inflictor, Prop_Data, "m_hOwnerEntity");
				if ((bIsDeveloper(victim, 4) || ((g_esPlayer[victim].g_iRewardTypes & MT_REWARD_DAMAGEBOOST) && g_esPlayer[victim].g_iFriendlyFire == 1)) && (attacker == -1 || (bIsValidClient(attacker, MT_CHECK_INDEX) && (!IsClientInGame(attacker) || GetClientUserId(attacker) != g_esPlayer[attacker].g_iUserID2))))
				{
					return Plugin_Handled;
				}
			}
		}
	}

	return Plugin_Continue;
}

Action OnInfectedTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (g_esGeneral.g_bPluginEnabled && (bIsInfected(victim) || bIsCommonInfected(victim) || bIsWitch(victim)) && damage > 0.0)
	{
		if (attacker == inflictor && bIsValidEntity(inflictor) && g_esGeneral.g_iTeamID[inflictor] == 3)
		{
			attacker = GetEntPropEnt(inflictor, Prop_Data, "m_hOwnerEntity");
			if (attacker == -1 || (bIsValidClient(attacker, MT_CHECK_INDEX) && (!IsClientInGame(attacker) || GetClientUserId(attacker) != g_esPlayer[attacker].g_iUserID)))
			{
				vRemovePlayerDamage(victim, damagetype);

				return Plugin_Handled;
			}
		}
		else if (bIsValidClient(attacker, MT_CHECK_INDEX))
		{
			if (g_esGeneral.g_iTeamID[inflictor] == 3 && (!IsClientInGame(attacker) || GetClientUserId(attacker) != g_esPlayer[attacker].g_iUserID || GetClientTeam(attacker) != 3))
			{
				vRemovePlayerDamage(victim, damagetype);

				return Plugin_Handled;
			}
		}
	}

	return Plugin_Continue;
}

Action OnPlayerTakeDamageAlive(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (g_esGeneral.g_bPluginEnabled && damage > 0.0 && bIsSurvivor(victim))
	{
		bool bDeveloper = (bIsDeveloper(victim, 6) || (g_esPlayer[victim].g_iRewardTypes & MT_REWARD_ATTACKBOOST));
		if (bDeveloper)
		{
			static int iIndex[2] = {-1, -1};
			int iReviver = GetClientOfUserId(g_esPlayer[victim].g_iReviver);
			if (bDeveloper || (bIsSurvivor(iReviver) && (bIsDeveloper(iReviver, 6) || (g_esPlayer[iReviver].g_iRewardTypes & MT_REWARD_ATTACKBOOST))))
			{
				if (iIndex[0] == -1)
				{
					iIndex[0] = iGetPatchIndex("MTPatch_ReviveInterrupt");
				}

				if (iIndex[0] != -1)
				{
					vInstallPatch(iIndex[0]);
				}
			}

			if (iIndex[1] == -1)
			{
				iIndex[1] = iGetPatchIndex("MTPatch_PunchAngle");
			}

			if (iIndex[1] != -1)
			{
				vInstallPatch(iIndex[1]);
			}

			SetEntPropFloat(victim, Prop_Send, "m_flVelocityModifier", 1.0);
		}
	}

	return Plugin_Continue;
}

void OnPlayerTakeDamageAlivePost(int victim, int attacker, int inflictor, float damage, int damagetype)
{
	static int iIndex[2] = {-1, -1};
	if (iIndex[0] == -1)
	{
		iIndex[0] = iGetPatchIndex("MTPatch_ReviveInterrupt");
	}

	if (iIndex[0] != -1)
	{
		vRemovePatch(iIndex[0]);
	}

	if (iIndex[1] == -1)
	{
		iIndex[1] = iGetPatchIndex("MTPatch_PunchAngle");
	}

	if (iIndex[1] != -1)
	{
		vRemovePatch(iIndex[1]);
	}
}

Action OnPlayerTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (g_esGeneral.g_bPluginEnabled && damage > 0.0)
	{
		char sClassname[32];
		int iLauncher = 0, iThrower = 0;
		if (bIsValidEntity(inflictor))
		{
			GetEntityClassname(inflictor, sClassname, sizeof sClassname);
			if (StrEqual(sClassname, "tank_rock"))
			{
				iLauncher = GetEntPropEnt(inflictor, Prop_Data, "m_hOwnerEntity");
				iThrower = GetEntPropEnt(inflictor, Prop_Data, "m_hThrower");
			}
		}

		bool bDeveloper = false, bRewarded = false;
		float flResistance = 0.0;
		if (bIsSurvivor(victim))
		{
			bDeveloper = bIsDeveloper(victim, 4);
			bRewarded = bDeveloper || (g_esPlayer[victim].g_iRewardTypes & MT_REWARD_DAMAGEBOOST);
			static int iIndex = -1;
			if (iIndex == -1)
			{
				iIndex = iGetPatchIndex("MTPatch_DoJumpHeight");
			}

			if (bIsDeveloper(victim, 11) || (g_esPlayer[victim].g_iRewardTypes & MT_REWARD_GODMODE))
			{
				if (StrEqual(sClassname, "tank_rock"))
				{
					RequestFrame(vDetonateRockFrame, EntIndexToEntRef(inflictor));
				}
				else if (((damagetype & DMG_DROWN) && iGetPlayerWaterLevel(victim) > MT_WATER_NONE) || ((damagetype & DMG_FALL) && !bIsSafeFalling(victim) && g_esPlayer[victim].g_bFatalFalling))
				{
					SetEntProp(victim, Prop_Data, "m_takedamage", 2, 1);

					return Plugin_Continue;
				}

				return Plugin_Handled;
			}
			else if ((g_esPlayer[victim].g_iFallPasses > 0 || (iIndex != -1 && g_esPatch[iIndex].g_iType == 2) || bIsDeveloper(victim, 5) || (g_esPlayer[victim].g_iRewardTypes & MT_REWARD_SPEEDBOOST)) && (damagetype & DMG_FALL) && (bIsSafeFalling(victim) || RoundToNearest(damage) < GetEntProp(victim, Prop_Data, "m_iHealth") || !g_esPlayer[victim].g_bFatalFalling))
			{
				if (g_esPlayer[victim].g_iFallPasses > 0)
				{
					g_esPlayer[victim].g_iFallPasses--;
				}

				return Plugin_Handled;
			}
			else if ((bIsDeveloper(victim, 8) || bIsDeveloper(victim, 10)) && StrEqual(sClassname, "insect_swarm"))
			{
				return Plugin_Handled;
			}
			else if (bIsTank(attacker))
			{
				flResistance = (bDeveloper && g_esDeveloper[victim].g_flDevDamageResistance > g_esPlayer[victim].g_flDamageResistance) ? g_esDeveloper[victim].g_flDevDamageResistance : g_esPlayer[victim].g_flDamageResistance;
				if (!bIsCoreAdminImmune(victim, attacker))
				{
					if (StrEqual(sClassname[7], "tank_claw") && g_esCache[attacker].g_flClawDamage >= 0.0)
					{
						damage = flGetScaledDamage(g_esCache[attacker].g_flClawDamage);
						damage = bIsPlayerIncapacitated(victim) ? (damage * g_esCache[attacker].g_flIncapDamageMultiplier) : damage;
						damage = (bRewarded && flResistance > 0.0) ? (damage * flResistance) : damage;

						return (g_esCache[attacker].g_flClawDamage > 0.0) ? Plugin_Changed : Plugin_Handled;
					}
					else if ((damagetype & DMG_CRUSH) && bIsValidEntity(inflictor) && HasEntProp(inflictor, Prop_Send, "m_isCarryable") && g_esCache[attacker].g_flHittableDamage >= 0.0)
					{
						damage = flGetScaledDamage(g_esCache[attacker].g_flHittableDamage);
						damage = bIsPlayerIncapacitated(victim) ? (damage * g_esCache[attacker].g_flIncapDamageMultiplier) : damage;
						damage = (bRewarded && flResistance > 0.0) ? (damage * flResistance) : damage;

						return (g_esCache[attacker].g_flHittableDamage > 0.0) ? Plugin_Changed : Plugin_Handled;
					}
					else if (StrEqual(sClassname, "tank_rock") && !bIsValidEntity(iLauncher) && g_esCache[attacker].g_flRockDamage >= 0.0)
					{
						damage = flGetScaledDamage(g_esCache[attacker].g_flRockDamage);
						damage = bIsPlayerIncapacitated(victim) ? (damage * g_esCache[attacker].g_flIncapDamageMultiplier) : damage;
						damage = (bRewarded && flResistance > 0.0) ? (damage * flResistance) : damage;

						return (g_esCache[attacker].g_flRockDamage > 0.0) ? Plugin_Changed : Plugin_Handled;
					}
				}
				else if (bRewarded && flResistance > 0.0)
				{
					damage *= flResistance;

					return Plugin_Changed;
				}
			}
			else if (bRewarded)
			{
				if (bDeveloper || g_esPlayer[victim].g_iThorns == 1)
				{
					if (bIsSpecialInfected(attacker))
					{
						char sDamageType[32];
						IntToString(damagetype, sDamageType, sizeof sDamageType);
						vDamagePlayer(attacker, victim, damage, sDamageType);
					}
					else if (bIsCommonInfected(attacker))
					{
						SDKHooks_TakeDamage(attacker, victim, victim, damage, damagetype);
					}
				}

				flResistance = (bDeveloper && g_esDeveloper[victim].g_flDevDamageResistance > g_esPlayer[victim].g_flDamageResistance) ? g_esDeveloper[victim].g_flDevDamageResistance : g_esPlayer[victim].g_flDamageResistance;
				if (flResistance > 0.0)
				{
					damage *= flResistance;

					return Plugin_Changed;
				}
			}
		}
		else if (bIsInfected(victim) || bIsCommonInfected(victim) || bIsWitch(victim))
		{
			g_esGeneral.g_iInfectedHealth[victim] = GetEntProp(victim, Prop_Data, "m_iHealth");

			bool bPlayer = bIsValidClient(attacker), bSurvivor = bIsSurvivor(attacker);
			float flDamage = 0.0;
			bDeveloper = bSurvivor && bIsDeveloper(attacker, 4), bRewarded = bDeveloper || (bSurvivor && (g_esPlayer[attacker].g_iRewardTypes & MT_REWARD_DAMAGEBOOST));
			if (bIsTank(victim))
			{
				if (StrEqual(sClassname, "tank_rock"))
				{
					RequestFrame(vDetonateRockFrame, EntIndexToEntRef(inflictor));

					return Plugin_Handled;
				}

				bool bBlockBullets = (((damagetype & DMG_BULLET) || (damagetype & DMG_BUCKSHOT)) && g_esCache[victim].g_iBulletImmunity == 1),
					bBlockExplosives = (((damagetype & DMG_BLAST) || (damagetype & DMG_BLAST_SURFACE) || (damagetype & DMG_AIRBOAT) || (damagetype & DMG_PLASMA)) && g_esCache[victim].g_iExplosiveImmunity == 1),
					bBlockFire = ((damagetype & DMG_BURN) && g_esCache[victim].g_iFireImmunity == 1),
					bBlockHittables = ((damagetype & DMG_CRUSH) && bIsValidEntity(inflictor) && HasEntProp(inflictor, Prop_Send, "m_isCarryable") && g_esCache[victim].g_iHittableImmunity == 1),
					bBlockMelee = (((damagetype & DMG_SLASH) || (damagetype & DMG_CLUB)) && g_esCache[victim].g_iMeleeImmunity == 1);

				if (bBlockBullets || bBlockExplosives || bBlockFire || bBlockHittables || bBlockMelee)
				{
					if (bRewarded)
					{
						if (bBlockBullets || bBlockMelee)
						{
							vKnockbackTank(victim, attacker, damagetype);
						}

						flDamage = (bDeveloper && g_esDeveloper[attacker].g_flDevDamageBoost > g_esPlayer[attacker].g_flDamageBoost) ? g_esDeveloper[attacker].g_flDevDamageBoost : g_esPlayer[attacker].g_flDamageBoost;
						if (flDamage > 0.0)
						{
							damage *= flDamage;

							return Plugin_Changed;
						}

						return Plugin_Continue;
					}

					if (bBlockBullets && ((!bBlockExplosives && ((damagetype & DMG_BLAST) || (damagetype & DMG_BLAST_SURFACE) || (damagetype & DMG_AIRBOAT) || (damagetype & DMG_PLASMA))) || (!bBlockFire && (damagetype & DMG_BURN))))
					{
						damagetype &= ~DMG_BULLET|DMG_BUCKSHOT;

						return Plugin_Changed;
					}

					if (bBlockExplosives && !bBlockBullets && ((damagetype & DMG_BULLET) || (damagetype & DMG_BUCKSHOT)))
					{
						damagetype &= ~DMG_BLAST|DMG_BLAST_SURFACE|DMG_AIRBOAT|DMG_PLASMA;

						return Plugin_Changed;
					}

					if (bBlockFire)
					{
						ExtinguishEntity(victim);

						if (!bBlockBullets && ((damagetype & DMG_BULLET) || (damagetype & DMG_BUCKSHOT)))
						{
							damagetype &= ~DMG_BURN;

							return Plugin_Changed;
						}
					}

					if (bPlayer && victim != attacker && (bBlockBullets || bBlockExplosives || bBlockHittables || bBlockMelee))
					{
						EmitSoundToAll(SOUND_METAL, victim);

						if (bPlayer && bBlockMelee)
						{
							float flTankPos[3];
							GetClientAbsOrigin(victim, flTankPos);

							switch (bSurvivor && (bIsDeveloper(attacker, 11) || (g_esPlayer[attacker].g_iRewardTypes & MT_REWARD_GODMODE)))
							{
								case true: vPushNearbyEntities(victim, flTankPos, 300.0, 100.0);
								case false: vPushNearbyEntities(victim, flTankPos);
							}
						}
					}

					return Plugin_Handled;
				}

				if ((damagetype & DMG_BURN) && g_esCache[victim].g_flBurnDuration > 0.0)
				{
					int iFlame = GetEntPropEnt(victim, Prop_Send, "m_hEffectEntity");
					if (bIsValidEntity(iFlame))
					{
						float flTime = GetGameTime();
						if (GetEntPropFloat(iFlame, Prop_Data, "m_flLifetime") > (flTime + g_esCache[victim].g_flBurnDuration))
						{
							SetEntPropFloat(iFlame, Prop_Data, "m_flLifetime", (flTime + g_esCache[victim].g_flBurnDuration));
						}
					}
				}

				if (bSurvivor)
				{
					if ((damagetype & DMG_BULLET) || (damagetype & DMG_BUCKSHOT) || (damagetype & DMG_CLUB) || (damagetype & DMG_SLASH))
					{
						vKnockbackTank(victim, attacker, damagetype);
					}

					if ((damagetype & DMG_BURN) && g_esGeneral.g_iCreditIgniters == 0)
					{
						if (bIsTank(victim) && bRewarded)
						{
							flDamage = (bDeveloper && g_esDeveloper[attacker].g_flDevDamageBoost > g_esPlayer[attacker].g_flDamageBoost) ? g_esDeveloper[attacker].g_flDevDamageBoost : g_esPlayer[attacker].g_flDamageBoost;
							if (flDamage > 0.0)
							{
								damage *= flDamage;
							}
						}

						inflictor = 0;
						attacker = 0;

						return Plugin_Changed;
					}
				}
			}
			else if (bSurvivor && (damagetype & DMG_BULLET))
			{
				bool bChanged = false;
				bDeveloper = bIsDeveloper(attacker, 9), bRewarded = !!(g_esPlayer[attacker].g_iRewardTypes & MT_REWARD_DAMAGEBOOST);
				if (bDeveloper || bRewarded)
				{
					if (bDeveloper || (bRewarded && g_esPlayer[attacker].g_iHollowpointAmmo == 1))
					{
						if (bIsCommonInfected(victim) || bIsWitch(victim))
						{
							if (g_bSecondGame)
							{
								if (GetEntProp(victim, Prop_Data, "m_iHealth") <= RoundToNearest(damage))
								{
									float flOrigin[3], flAngles[3];
									GetEntPropVector(victim, Prop_Data, "m_vecOrigin", flOrigin);
									GetEntPropVector(victim, Prop_Data, "m_angRotation", flAngles);
									flOrigin[2] += 48.0;

									RequestFrame(vInfectedTransmitFrame, EntIndexToEntRef(victim));
									vAttachParticle2(flOrigin, flAngles, PARTICLE_GORE, 0.2);
								}
							}
							else
							{
								bChanged = true;
								damagetype |= DMG_DISSOLVE;
							}
						}
					}

					if (bDeveloper || (bRewarded && g_esPlayer[attacker].g_iSledgehammerRounds == 1))
					{
						if (bIsSpecialInfected(victim))
						{
							vPerformKnockback(victim, attacker);
						}
						else if (bIsCommonInfected(victim) || bIsWitch(victim))
						{
							bRewarded = bDeveloper || (bSurvivor && (g_esPlayer[attacker].g_iRewardTypes & MT_REWARD_DAMAGEBOOST));
							if (bRewarded)
							{
								bDeveloper = bSurvivor && bIsDeveloper(attacker, 4);
								flDamage = (bDeveloper && g_esDeveloper[attacker].g_flDevDamageBoost > g_esPlayer[attacker].g_flDamageBoost) ? g_esDeveloper[attacker].g_flDevDamageBoost : g_esPlayer[attacker].g_flDamageBoost;
								if (flDamage > 0.0)
								{
									bChanged = true;
									damage *= flDamage;
								}
							}

							bChanged = true;
							damagetype |= DMG_BUCKSHOT;
						}
					}

					if (bChanged)
					{
						return Plugin_Changed;
					}
				}
			}

			bDeveloper = bSurvivor && bIsDeveloper(attacker, 4);
			bRewarded = bDeveloper || (bSurvivor && (g_esPlayer[attacker].g_iRewardTypes & MT_REWARD_DAMAGEBOOST));
			if (bRewarded)
			{
				flDamage = (bDeveloper && g_esDeveloper[attacker].g_flDevDamageBoost > g_esPlayer[attacker].g_flDamageBoost) ? g_esDeveloper[attacker].g_flDevDamageBoost : g_esPlayer[attacker].g_flDamageBoost;
				if (flDamage > 0.0)
				{
					damage *= flDamage;

					return Plugin_Changed;
				}
			}
			else if ((bIsTankSupported(attacker) && victim != attacker) || (bIsTankSupported(iLauncher) && victim != iLauncher) || (bIsTankSupported(iThrower) && victim != iThrower))
			{
				if (StrEqual(sClassname[7], "tank_claw"))
				{
					return Plugin_Continue;
				}

				if (StrEqual(sClassname, "tank_rock") || (damagetype & DMG_BLAST) || (damagetype & DMG_BLAST_SURFACE) || (damagetype & DMG_AIRBOAT) || (damagetype & DMG_PLASMA) || (damagetype & DMG_BURN))
				{
					vRemovePlayerDamage(victim, damagetype);

					if (StrEqual(sClassname, "tank_rock"))
					{
						RequestFrame(vDetonateRockFrame, EntIndexToEntRef(inflictor));
					}

					return Plugin_Handled;
				}
			}
			else if (victim == attacker)
			{
				return Plugin_Handled;
			}
		}
	}

	return Plugin_Continue;
}

Action OnPropTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (g_esGeneral.g_bPluginEnabled && damage > 0.0)
	{
		if (attacker == inflictor && bIsValidEntity(inflictor) && g_esGeneral.g_iTeamID2[inflictor] == 2)
		{
			attacker = GetEntPropEnt(inflictor, Prop_Data, "m_hOwnerEntity");
			if (attacker == -1 || (bIsValidClient(attacker, MT_CHECK_INDEX) && ((bIsValidClient(victim) && GetClientTeam(victim) == GetClientTeam(attacker) && (bIsDeveloper(attacker, 4) || ((g_esPlayer[attacker].g_iRewardTypes & MT_REWARD_DAMAGEBOOST) && g_esPlayer[attacker].g_iFriendlyFire == 1))) || !IsClientInGame(attacker) || GetClientUserId(attacker) != g_esPlayer[attacker].g_iUserID2)))
			{
				return Plugin_Handled;
			}
		}
		else if (bIsValidClient(attacker, MT_CHECK_INDEX))
		{
			if (g_esGeneral.g_iTeamID2[inflictor] == 2 && ((bIsValidClient(victim) && GetClientTeam(victim) == GetClientTeam(attacker) && (bIsDeveloper(attacker, 4) || ((g_esPlayer[attacker].g_iRewardTypes & MT_REWARD_DAMAGEBOOST) && g_esPlayer[attacker].g_iFriendlyFire == 1))) || !IsClientInGame(attacker) || GetClientUserId(attacker) != g_esPlayer[attacker].g_iUserID2 || GetClientTeam(attacker) != 2))
			{
				return Plugin_Handled;
			}
		}
	}

	return Plugin_Continue;
}

void OnPlayerTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype)
{
	if (g_esGeneral.g_bPluginEnabled && damage >= 1.0)
	{
		if (bIsTank(attacker) && bIsSurvivor(victim))
		{
			g_esPlayer[attacker].g_iSurvivorDamage += RoundToNearest(damage);

			char sClassname[32];
			if (bIsValidEntity(inflictor))
			{
				GetEntityClassname(inflictor, sClassname, sizeof sClassname);
			}

			if (StrEqual(sClassname[7], "tank_claw"))
			{
				g_esPlayer[attacker].g_iClawCount++;
				g_esPlayer[attacker].g_iClawDamage += RoundToNearest(damage);
			}
			else if (StrEqual(sClassname, "tank_rock"))
			{
				g_esPlayer[attacker].g_iRockCount++;
				g_esPlayer[attacker].g_iRockDamage += RoundToNearest(damage);
			}
			else if ((damagetype & DMG_CRUSH) && bIsValidEntity(inflictor) && HasEntProp(inflictor, Prop_Send, "m_isCarryable"))
			{
				g_esPlayer[attacker].g_iPropCount++;
				g_esPlayer[attacker].g_iPropDamage += RoundToNearest(damage);
			}
			else
			{
				g_esPlayer[attacker].g_iMiscCount++;
				g_esPlayer[attacker].g_iMiscDamage += RoundToNearest(damage);
			}
		}
		else if (bIsInfected(victim) || bIsCommonInfected(victim) || bIsWitch(victim))
		{
			if (bIsSurvivor(attacker) && g_esGeneral.g_iInfectedHealth[victim] > GetEntProp(victim, Prop_Data, "m_iHealth"))
			{
				vLifeLeech(attacker, damagetype, victim);
			}

			if (bIsInfected(victim))
			{
				if ((damagetype & DMG_BURN) && bIsSurvivor(attacker))
				{
					g_esPlayer[victim].g_iLastFireAttacker = attacker;
				}
				else if (!bIsPlayerBurning(victim) || !bIsValidClient(attacker))
				{
					g_esPlayer[victim].g_iLastFireAttacker = 0;
				}
			}
		}
	}
}

// PreThinkPost hooks

void OnRainbowPreThinkPost(int player)
{
	if (!bIsValidClient(player) || !g_esPlayer[player].g_bRainbowColor)
	{
		g_esPlayer[player].g_bRainbowColor = false;

		SDKUnhook(player, SDKHook_PreThinkPost, OnRainbowPreThinkPost);

		return;
	}

	bool bHook = false, bRainbow = false;
	int iColor[4];
	GetEntityRenderColor(player, iColor[0], iColor[1], iColor[2], iColor[3]);
	iColor[0] = RoundToNearest((Cosine((GetGameTime() * 1.0) + player) * 127.5) + 127.5);
	iColor[1] = RoundToNearest((Cosine((GetGameTime() * 1.0) + player + 2) * 127.5) + 127.5);
	iColor[2] = RoundToNearest((Cosine((GetGameTime() * 1.0) + player + 4) * 127.5) + 127.5);
	if (bIsSurvivor(player))
	{
		bool bDeveloper = bIsDeveloper(player, 0);
		if (g_esPlayer[player].g_bApplyVisuals[0] && g_esPlayer[player].g_flVisualTime[0] != -1.0 && g_esPlayer[player].g_flVisualTime[0] > GetGameTime() && StrEqual(g_esPlayer[player].g_sScreenColor, "rainbow", false))
		{
			g_esPlayer[player].g_iScreenColorVisual[0] = iColor[0];
			g_esPlayer[player].g_iScreenColorVisual[1] = iColor[1];
			g_esPlayer[player].g_iScreenColorVisual[2] = iColor[2];
			g_esPlayer[player].g_iScreenColorVisual[3] = 50;
		}

		if ((g_esPlayer[player].g_bApplyVisuals[4] && g_esPlayer[player].g_flVisualTime[4] != -1.0 && g_esPlayer[player].g_flVisualTime[4] > GetGameTime()) || bDeveloper)
		{
			switch (bDeveloper)
			{
				case true: bRainbow = StrEqual(g_esDeveloper[player].g_sDevFlashlight, "rainbow", false);
				case false: bRainbow = StrEqual(g_esPlayer[player].g_sLightColor, "rainbow", false);
			}

			if (bRainbow)
			{
				bHook = true;

				vSetSurvivorFlashlight(player, iColor);
			}
		}

		if ((g_esPlayer[player].g_bApplyVisuals[5] && g_esPlayer[player].g_flVisualTime[5] != -1.0 && g_esPlayer[player].g_flVisualTime[5] > GetGameTime()) || bDeveloper)
		{
			switch (bDeveloper)
			{
				case true: bRainbow = StrEqual(g_esDeveloper[player].g_sDevSkinColor, "rainbow", false);
				case false: bRainbow = StrEqual(g_esPlayer[player].g_sBodyColor, "rainbow", false);
			}

			if (bRainbow)
			{
				bHook = true;

				SetEntityRenderColor(player, iColor[0], iColor[1], iColor[2], iColor[3]);
			}
		}

		if (g_bSecondGame && ((g_esPlayer[player].g_bApplyVisuals[6] && g_esPlayer[player].g_flVisualTime[6] != -1.0 && g_esPlayer[player].g_flVisualTime[6] > GetGameTime()) || bDeveloper) && !g_esPlayer[player].g_bVomited)
		{
			switch (bDeveloper)
			{
				case true: bRainbow = StrEqual(g_esDeveloper[player].g_sDevGlowOutline, "rainbow", false);
				case false: bRainbow = StrEqual(g_esPlayer[player].g_sOutlineColor, "rainbow", false);
			}

			if (bRainbow)
			{
				bHook = true;

				vSetSurvivorGlow(player, iColor[0], iColor[1], iColor[2]);
			}
		}
	}
	else if (bIsTank(player))
	{
		bRainbow = StrEqual(g_esCache[player].g_sSkinColor, "rainbow", false);
		if (bRainbow)
		{
			bHook = true;

			SetEntityRenderColor(player, iColor[0], iColor[1], iColor[2], iColor[3]);
		}

		int iProp = -1;
		if (bRainbow && bIsValidEntRef(g_esPlayer[player].g_iBlur))
		{
			bHook = true;
			iProp = EntRefToEntIndex(g_esPlayer[player].g_iBlur);
			if (bIsValidEntity(iProp))
			{
				SetEntityRenderColor(iProp, iColor[0], iColor[1], iColor[2], iColor[3]);
			}
		}

		if (g_bSecondGame && g_esCache[player].g_iGlowEnabled == 1 && !g_esPlayer[player].g_bVomited)
		{
			bRainbow = StrEqual(g_esCache[player].g_sGlowColor, "rainbow", false);
			if (bRainbow)
			{
				bHook = true;
				g_esCache[player].g_iGlowColor[0] = iColor[0];
				g_esCache[player].g_iGlowColor[1] = iColor[1];
				g_esCache[player].g_iGlowColor[2] = iColor[2];
				vSetTankGlow(player);
			}
		}

		bool bRainbow2[4];
		bRainbow2[0] = StrEqual(g_esCache[player].g_sOzTankColor, "rainbow", false);
		bRainbow2[1] = StrEqual(g_esCache[player].g_sFlameColor, "rainbow", false);
		bRainbow2[2] = StrEqual(g_esCache[player].g_sTireColor, "rainbow", false);
		bRainbow2[3] = StrEqual(g_esCache[player].g_sRockColor, "rainbow", false);

		for (int iPos = 0; iPos < (sizeof esPlayer::g_iRock); iPos++)
		{
			if (iPos < (sizeof esPlayer::g_iOzTank))
			{
				if (bRainbow2[0] && bIsValidEntRef(g_esPlayer[player].g_iOzTank[iPos]))
				{
					bHook = true;
					iProp = EntRefToEntIndex(g_esPlayer[player].g_iOzTank[iPos]);
					if (bIsValidEntity(iProp))
					{
						SetEntityRenderColor(iProp, iColor[0], iColor[1], iColor[2], iColor[3]);
					}
				}

				if (bRainbow2[1] && bIsValidEntRef(g_esPlayer[player].g_iFlame[iPos]))
				{
					bHook = true;
					iProp = EntRefToEntIndex(g_esPlayer[player].g_iFlame[iPos]);
					if (bIsValidEntity(iProp))
					{
						SetEntityRenderColor(iProp, iColor[0], iColor[1], iColor[2], iColor[3]);
					}
				}
			}

			if (iPos < (sizeof esPlayer::g_iTire))
			{
				if (bRainbow2[2] && bIsValidEntRef(g_esPlayer[player].g_iTire[iPos]))
				{
					bHook = true;
					iProp = EntRefToEntIndex(g_esPlayer[player].g_iTire[iPos]);
					if (bIsValidEntity(iProp))
					{
						SetEntityRenderColor(iProp, iColor[0], iColor[1], iColor[2], iColor[3]);
					}
				}
			}

			if (bRainbow2[3] && bIsValidEntRef(g_esPlayer[player].g_iRock[iPos]))
			{
				bHook = true;
				iProp = EntRefToEntIndex(g_esPlayer[player].g_iRock[iPos]);
				if (bIsValidEntity(iProp))
				{
					SetEntityRenderColor(iProp, iColor[0], iColor[1], iColor[2], iColor[3]);
				}
			}
		}

		bRainbow = StrEqual(g_esCache[player].g_sPropTankColor, "rainbow", false);
		if (bRainbow && bIsValidEntRef(g_esPlayer[player].g_iPropaneTank))
		{
			bHook = true;
			iProp = EntRefToEntIndex(g_esPlayer[player].g_iPropaneTank);
			if (bIsValidEntity(iProp))
			{
				SetEntityRenderColor(iProp, iColor[0], iColor[1], iColor[2], iColor[3]);
			}
		}

		bRainbow = StrEqual(g_esCache[player].g_sFlashlightColor, "rainbow", false);
		if (bRainbow && bIsValidEntRef(g_esPlayer[player].g_iFlashlight))
		{
			bHook = true;
			iProp = EntRefToEntIndex(g_esPlayer[player].g_iFlashlight);
			if (bIsValidEntity(iProp))
			{
				char sColor[16];
				FormatEx(sColor, sizeof sColor, "%i %i %i %i", iGetRandomColor(iColor[0]), iGetRandomColor(iColor[1]), iGetRandomColor(iColor[2]), iGetRandomColor(iColor[3]));
				DispatchKeyValue(g_esPlayer[player].g_iFlashlight, "_light", sColor);
			}
		}

		for (int iPos = 0; iPos < (sizeof esPlayer::g_iThrownRock); iPos++)
		{
			if (bRainbow2[3] && bIsValidEntRef(g_esPlayer[player].g_iThrownRock[iPos]))
			{
				bHook = true;
				iProp = EntRefToEntIndex(g_esPlayer[player].g_iThrownRock[iPos]);
				if (bIsValidEntity(iProp))
				{
					SetEntityRenderColor(iProp, iColor[0], iColor[1], iColor[2], iColor[3]);
				}
			}
		}
	}

	if (!bHook)
	{
		g_esPlayer[player].g_bRainbowColor = false;

		SDKUnhook(player, SDKHook_PreThinkPost, OnRainbowPreThinkPost);
	}
}

void OnSpeedPreThinkPost(int survivor)
{
	switch (bIsSurvivor(survivor))
	{
		case true:
		{
			bool bDeveloper = bIsDeveloper(survivor, 5);
			if (bDeveloper || (g_esPlayer[survivor].g_iRewardTypes & MT_REWARD_SPEEDBOOST))
			{
				float flSpeed = (bDeveloper && g_esDeveloper[survivor].g_flDevSpeedBoost > g_esPlayer[survivor].g_flSpeedBoost) ? g_esDeveloper[survivor].g_flDevSpeedBoost : g_esPlayer[survivor].g_flSpeedBoost;

				switch (flSpeed > 0.0)
				{
					case true: SetEntPropFloat(survivor, Prop_Send, "m_flLaggedMovementValue", flSpeed);
					case false: SDKUnhook(survivor, SDKHook_PreThinkPost, OnSpeedPreThinkPost);
				}
			}
			else
			{
				SDKUnhook(survivor, SDKHook_PreThinkPost, OnSpeedPreThinkPost);
				SetEntPropFloat(survivor, Prop_Send, "m_flLaggedMovementValue", 1.0);
			}
		}
		case false:
		{
			SDKUnhook(survivor, SDKHook_PreThinkPost, OnSpeedPreThinkPost);
			SetEntPropFloat(survivor, Prop_Send, "m_flLaggedMovementValue", 1.0);
		}
	}
}

// PostThinkPost hooks

void OnSurvivorPostThinkPost(int survivor)
{
	switch (bIsSurvivor(survivor))
	{
		case true:
		{
			if (bIsDeveloper(survivor, 6) || (g_esPlayer[survivor].g_iRewardTypes & MT_REWARD_ATTACKBOOST))
			{
				bool bFast = false;
				if (g_bSecondGame)
				{
					char sModel[40];
					int iSequence = GetEntProp(survivor, Prop_Send, "m_nSequence");
					GetEntPropString(survivor, Prop_Data, "m_ModelName", sModel, sizeof sModel);

					switch (sModel[29])
					{
						case 'b': bFast = (iSequence == 620 || (627 <= iSequence <= 630) || iSequence == 667 || iSequence == 671 || iSequence == 672 || iSequence == 680);
						case 'd': bFast = (iSequence == 629 || (635 <= iSequence <= 638) || iSequence == 664 || iSequence == 678 || iSequence == 679 || iSequence == 687);
						case 'c': bFast = (iSequence == 621 || (627 <= iSequence <= 630) || iSequence == 656 || iSequence == 660 || iSequence == 661 || iSequence == 669);
						case 'h': bFast = (iSequence == 625 || (632 <= iSequence <= 635) || iSequence == 671 || iSequence == 675 || iSequence == 676 || iSequence == 684);
						case 'v': bFast = (iSequence == 528 || (535 <= iSequence <= 538) || iSequence == 759 || iSequence == 763 || iSequence == 764 || iSequence == 772);
						case 'n': bFast = (iSequence == 537 || (544 <= iSequence <= 547) || iSequence == 809 || iSequence == 819 || iSequence == 823 || iSequence == 824);
						case 'e': bFast = (iSequence == 531 || (539 <= iSequence <= 541) || iSequence == 762 || iSequence == 766 || iSequence == 767 || iSequence == 775);
						case 'a': bFast = (iSequence == 528 || (535 <= iSequence <= 538) || iSequence == 759 || iSequence == 763 || iSequence == 764 || iSequence == 772);
					}
				}

				switch (bFast)
				{
					case true: SetEntPropFloat(survivor, Prop_Send, "m_flPlaybackRate", 2.0);
					case false:
					{
						float flTime = GetGameTime();
						if (g_esPlayer[survivor].g_flStaggerTime > flTime)
						{
							return;
						}

						float flStagger = GetEntPropFloat(survivor, Prop_Send, "m_staggerTimer", 1);
						if (flStagger <= (flTime + g_esGeneral.g_flTickInterval))
						{
							return;
						}

						flStagger = (((flStagger - flTime) / 2.0) + flTime);
						SetEntPropFloat(survivor, Prop_Send, "m_staggerTimer", flStagger, 1);
						g_esPlayer[survivor].g_flStaggerTime = flStagger;
					}
				}
			}
			else
			{
				SDKUnhook(survivor, SDKHook_PostThinkPost, OnSurvivorPostThinkPost);
			}
		}
		case false: SDKUnhook(survivor, SDKHook_PostThinkPost, OnSurvivorPostThinkPost);
	}
}

void OnTankPostThinkPost(int tank)
{
	switch (bIsTank(tank) && g_bSecondGame && g_esCache[tank].g_iSkipTaunt == 1)
	{
		case true:
		{
			switch (GetEntProp(tank, Prop_Send, "m_nSequence"))
			{
				case 16, 17, 18, 19, 20, 21, 22, 23: SetEntPropFloat(tank, Prop_Send, "m_flPlaybackRate", 10.0);
				default: SDKUnhook(tank, SDKHook_PostThinkPost, OnTankPostThinkPost);
			}
		}
		case false: SDKUnhook(tank, SDKHook_PostThinkPost, OnTankPostThinkPost);
	}
}

void OnEffectSpawnPost(int entity)
{
	int iAttacker = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");
	if (bIsValidClient(iAttacker, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE))
	{
		g_esGeneral.g_iTeamID[entity] = GetClientTeam(iAttacker);

		if (bIsSurvivor(iAttacker) && (bIsDeveloper(iAttacker, 4) || ((g_esPlayer[iAttacker].g_iRewardTypes & MT_REWARD_DAMAGEBOOST) && g_esPlayer[iAttacker].g_iFriendlyFire == 1)))
		{
			g_esGeneral.g_iTeamID2[entity] = g_esGeneral.g_iTeamID[entity];
		}
	}
}

void OnInfectedSpawnPost(int entity)
{
	if (bIsValidEntity(entity))
	{
		SDKHook(entity, SDKHook_OnTakeDamage, OnInfectedTakeDamage);
		SDKHook(entity, SDKHook_OnTakeDamage, OnPlayerTakeDamage);
		SDKHook(entity, SDKHook_OnTakeDamagePost, OnPlayerTakeDamagePost);
	}
}

void OnPropSpawnPost(int entity)
{
	char sModel[64];
	GetEntPropString(entity, Prop_Data, "m_ModelName", sModel, sizeof sModel);
	if (StrEqual(sModel, MODEL_OXYGENTANK) || StrEqual(sModel, MODEL_PROPANETANK) || StrEqual(sModel, MODEL_GASCAN) || (g_bSecondGame && StrEqual(sModel, MODEL_FIREWORKCRATE)))
	{
		SDKHook(entity, SDKHook_OnTakeDamage, OnPropTakeDamage);
	}
}

// SetTransmit hooks

Action OnInfectedSetTransmit(int entity, int client)
{
	return Plugin_Handled;
}

Action OnPropSetTransmit(int entity, int client)
{
	int iOwner = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");
	if (g_esGeneral.g_bPluginEnabled && bIsValidClient(iOwner) && bIsValidClient(client) && iOwner == client && !bIsTankInThirdPerson(client))
	{
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

// TouchPost hooks

void OnDoorTouchPost(int client, int entity)
{
	float flTime = GetGameTime();
	if (g_esGeneral.g_bPluginEnabled && bIsSurvivor(client) && (bIsDeveloper(client, 5) || bIsDeveloper(client, 11) || ((g_esPlayer[client].g_iRewardTypes & MT_REWARD_SPEEDBOOST) && g_esPlayer[client].g_iBurstDoors == 1)) && entity > MaxClients && g_esPlayer[client].g_flLastPushTime < flTime)
	{
		char sClassname[32];
		GetEntityClassname(entity, sClassname, sizeof sClassname);
		if (!strncmp(sClassname, "prop_door_rotating", 18) && GetEntProp(entity, Prop_Data, "m_eDoorState") == 0)
		{
			g_esPlayer[client].g_flLastPushTime = flTime + 0.5;

			float flSpeed = GetEntPropFloat(entity, Prop_Data, "m_flSpeed"), flTempSpeed = GetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue") * 200.0;
			SetEntPropFloat(entity, Prop_Data, "m_flSpeed", flTempSpeed);
			AcceptEntityInput(entity, "PlayerOpen", client);
			SetEntPropFloat(entity, Prop_Data, "m_flSpeed", flSpeed);
		}
	}
}

// Weapon hooks

Action OnWeaponCanSwitchTo(int client)
{
	SDKUnhook(client, SDKHook_WeaponCanSwitchTo, OnWeaponCanSwitchTo);

	return Plugin_Handled;
}

void OnWeaponEquipPost(int client, int weapon)
{
	if (g_esGeneral.g_bPluginEnabled && bIsSurvivor(client) && weapon > MaxClients)
	{
		vCheckGunClipSizes(client);

		char sWeapon[32];
		GetEntityClassname(weapon, sWeapon, sizeof sWeapon);
		if (GetPlayerWeaponSlot(client, 2) == weapon)
		{
			strcopy(g_esPlayer[client].g_sStoredThrowable, sizeof esPlayer::g_sStoredThrowable, sWeapon);
		}
		else if (GetPlayerWeaponSlot(client, 3) == weapon)
		{
			strcopy(g_esPlayer[client].g_sStoredMedkit, sizeof esPlayer::g_sStoredMedkit, sWeapon);
		}
		else if (GetPlayerWeaponSlot(client, 4) == weapon)
		{
			strcopy(g_esPlayer[client].g_sStoredPills, sizeof esPlayer::g_sStoredPills, sWeapon);
		}
	}
}

void OnWeaponSwitchPost(int client, int weapon)
{
	if (g_esGeneral.g_bPluginEnabled && g_bSecondGame && bIsSurvivor(client) && bIsDeveloper(client, 2) && weapon > MaxClients)
	{
		RequestFrame(vWeaponSkinFrame, GetClientUserId(client));
	}
}

// Sound hooks

Action FallSoundHook(int clients[MAXPLAYERS], int &numClients, char sample[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags, char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
	if (g_esGeneral.g_bPluginEnabled && bIsSurvivor(entity))
	{
		static int iIndex = -1;
		if (iIndex == -1)
		{
			iIndex = iGetPatchIndex("MTPatch_DoJumpHeight");
		}

		if (g_esPlayer[entity].g_iFallPasses > 0 || (iIndex != -1 && g_esPatch[iIndex].g_iType == 2) || bIsDeveloper(entity, 5) || bIsDeveloper(entity, 11) || (g_esPlayer[entity].g_iRewardTypes & MT_REWARD_SPEEDBOOST) || (g_esPlayer[entity].g_iRewardTypes & MT_REWARD_GODMODE))
		{
			float flOrigin[3];
			GetEntPropVector(entity, Prop_Data, "m_vecOrigin", flOrigin);
			if ((g_esPlayer[entity].g_bFallDamage && !g_esPlayer[entity].g_bFatalFalling) || (0.0 < (g_esPlayer[entity].g_flPreFallZ - flOrigin[2]) < 900.0 && !g_esPlayer[entity].g_bFalling))
			{
				if (StrEqual(sample, SOUND_NULL, false))
				{
					return Plugin_Stop;
				}
				else if (0 <= StrContains(sample, SOUND_DAMAGE, false) <= 1 || 0 <= StrContains(sample, SOUND_DAMAGE2, false) <= 1)
				{
					g_esPlayer[entity].g_bFallDamage = false;

					return Plugin_Stop;
				}
			}
		}
	}

	return Plugin_Continue;
}

Action RockSoundHook(int clients[MAXPLAYERS], int &numClients, char sample[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags, char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
	if (StrEqual(sample, SOUND_THROWN, false))
	{
		numClients = 0;

		return Plugin_Changed;
	}

	return Plugin_Continue;
}

Action VoiceSoundHook(int clients[MAXPLAYERS], int &numClients, char sample[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags, char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
	if (g_esGeneral.g_bPluginEnabled && bIsSurvivor(entity) && channel == SNDCHAN_VOICE)
	{
		bool bDeveloper = bIsDeveloper(entity, 0) || bIsDeveloper(entity, 2) || bIsDeveloper(entity, 11);
		if (bDeveloper || (g_esPlayer[entity].g_iRewardVisuals & MT_VISUAL_VOICEPITCH))
		{
			int iPitch = (bDeveloper && g_esDeveloper[entity].g_iDevVoicePitch > 0) ? g_esDeveloper[entity].g_iDevVoicePitch : g_esPlayer[entity].g_iVoicePitch;
			if (iPitch > 0 && iPitch != pitch)
			{
				pitch = iPitch;
				flags |= SND_CHANGEPITCH;

				return Plugin_Changed;
			}
		}
	}

	return Plugin_Continue;
}

/**
 * UserMessage hooks
 **/

void vHookUserMessage(bool toggle)
{
	if (g_esGeneral.g_umSayText2 == INVALID_MESSAGE_ID)
	{
		return;
	}

	switch (toggle)
	{
		case true: HookUserMessage(g_esGeneral.g_umSayText2, umNameChange, true);
		case false: UnhookUserMessage(g_esGeneral.g_umSayText2, umNameChange, true);
	}
}

Action umNameChange(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init)
{
	if (!g_esGeneral.g_bHideNameChange)
	{
		return Plugin_Continue;
	}

	msg.ReadByte();
	msg.ReadByte();

	char sMessage[255];
	msg.ReadString(sMessage, sizeof sMessage, true);
	if (StrEqual(sMessage, "#Cstrike_Name_Change"))
	{
		g_esGeneral.g_bHideNameChange = false;

		return Plugin_Handled;
	}

	return Plugin_Continue;
}

/**
 * DHooks Detour setup
 **/

void vReadDetourSettings(const char[] key, const char[] value)
{
	int iIndex = g_esGeneral.g_iDetourCount;
	g_esDetour[iIndex].g_bLog = !!iGetKeyValueEx(key, "Log", "Log", "Log", "Log", g_esDetour[iIndex].g_bLog, value, 0, 1);
	g_esDetour[iIndex].g_iType = iGetKeyValueEx(key, "Type", "Type", "Type", "Type", g_esDetour[iIndex].g_iType, value, 0, 4);
	g_esDetour[iIndex].g_iPreHook = iGetKeyValueEx(key, "PreHook", "Pre-Hook", "Pre_Hook", "pre", g_esDetour[iIndex].g_iPreHook, value, 0, 2);
	g_esDetour[iIndex].g_iPostHook = iGetKeyValueEx(key, "PostHook", "Post-Hook", "Post_Hook", "post", g_esDetour[iIndex].g_iPostHook, value, 0, 2);

	vGetKeyValueEx(key, "CvarCheck", "Cvar Check", "Cvar_Check", "cvars", g_esDetour[iIndex].g_sCvars, sizeof esDetour::g_sCvars, value);
}

void vRegisterDetour(const char[] name, bool reg)
{
	if (!reg)
	{
		g_esGeneral.g_bOverrideDetour = true;

		return;
	}

	int iIndex = g_esGeneral.g_iDetourCount;
	if (g_esDetour[iIndex].g_iType == 0)
	{
		return;
	}
	else if (g_esDetour[iIndex].g_iType == 1 || g_esDetour[iIndex].g_iType == 3)
	{
		if (bIsConVarConflictFound(name, g_esDetour[iIndex].g_sCvars, "disabling", g_esDetour[iIndex].g_bLog))
		{
			g_esDetour[iIndex].g_bBypassNeeded = true;
		}
	}

	g_esGeneral.g_iDetourCount++;

	if (g_esDetour[iIndex].g_bLog)
	{
		vLogMessage(-1, _, "%s Registered the \"%s\" detour.", MT_TAG, name);
	}
}

void vRegisterDetours()
{
	char sFilePath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sFilePath, sizeof sFilePath, "%s%s.cfg", MT_CONFIG_FILEPATH, MT_CONFIG_FILE_DETOURS);
	if (!MT_FileExists(MT_CONFIG_FILEPATH, (MT_CONFIG_FILE_DETOURS ... ".cfg"), sFilePath, sFilePath, sizeof sFilePath))
	{
		LogError("%s Unable to load the \"%s\" config file.", MT_TAG, sFilePath);

		return;
	}

	SMCParser smcDetours = smcSetupParser(sFilePath, SMCParseStart_Detours, SMCNewSection_Detours, SMCKeyValues_Detours, SMCEndSection_Detours, SMCRawLine_Detours, SMCParseEnd_Detours);
	if (smcDetours != null)
	{
		delete smcDetours;
	}
}

void vSetupDetour(DynamicDetour &detourHandle, const char[] name)
{
	int iIndex = iGetDetourIndex(name);
	if (iIndex == -1 || g_esDetour[iIndex].g_iType == 0 || ((g_esDetour[iIndex].g_iType == 1 || g_esDetour[iIndex].g_iType == 3) && g_esDetour[iIndex].g_bBypassNeeded))
	{
		return;
	}

	detourHandle = DynamicDetour.FromConf(g_esGeneral.g_gdMutantTanks, name);
	if (detourHandle == null)
	{
		LogError("%s Failed to detour: %s", MT_TAG, name);

		return;
	}

	if (g_esDetour[iIndex].g_bLog)
	{
		vLogMessage(-1, _, "%s Setup the \"%s\" detour.", MT_TAG, name);
	}
}

void vSetupDetours()
{
	vSetupDetour(g_esGeneral.g_ddActionCompleteDetour, "MTDetour_CFirstAidKit::OnActionComplete");
	vSetupDetour(g_esGeneral.g_ddBaseEntityCreateDetour, "MTDetour_CBaseEntity::Create");
	vSetupDetour(g_esGeneral.g_ddBaseEntityGetGroundEntityDetour, "MTDetour_CBaseEntity::GetGroundEntity");
	vSetupDetour(g_esGeneral.g_ddBeginChangeLevelDetour, "MTDetour_CTerrorPlayer::OnBeginChangeLevel");
	vSetupDetour(g_esGeneral.g_ddCanDeployForDetour, "MTDetour_CTerrorWeapon::CanDeployFor");
	vSetupDetour(g_esGeneral.g_ddCheckJumpButtonDetour, "MTDetour_CTerrorGameMovement::CheckJumpButton");
	vSetupDetour(g_esGeneral.g_ddDeathFallCameraEnableDetour, "MTDetour_CDeathFallCamera::Enable");
	vSetupDetour(g_esGeneral.g_ddDoAnimationEventDetour, "MTDetour_CTerrorPlayer::DoAnimationEvent");
	vSetupDetour(g_esGeneral.g_ddDoJumpDetour, "MTDetour_CTerrorGameMovement::DoJump");
	vSetupDetour(g_esGeneral.g_ddEnterGhostStateDetour, "MTDetour_CTerrorPlayer::OnEnterGhostState");
	vSetupDetour(g_esGeneral.g_ddEnterStasisDetour, "MTDetour_Tank::EnterStasis");
	vSetupDetour(g_esGeneral.g_ddEventKilledDetour, "MTDetour_CTerrorPlayer::Event_Killed");
	vSetupDetour(g_esGeneral.g_ddExtinguishDetour, "MTDetour_CTerrorPlayer::Extinguish");
	vSetupDetour(g_esGeneral.g_ddFallingDetour, "MTDetour_CTerrorPlayer::OnFalling");
	vSetupDetour(g_esGeneral.g_ddFinishHealingDetour, "MTDetour_CFirstAidKit::FinishHealing");
	vSetupDetour(g_esGeneral.g_ddFireBulletDetour, "MTDetour_CTerrorGun::FireBullet");
	vSetupDetour(g_esGeneral.g_ddFirstSurvivorLeftSafeAreaDetour, "MTDetour_CDirector::OnFirstSurvivorLeftSafeArea");
	vSetupDetour(g_esGeneral.g_ddFlingDetour, "MTDetour_CTerrorPlayer::Fling");
	vSetupDetour(g_esGeneral.g_ddGetMaxClip1Detour, "MTDetour_CBaseCombatWeapon::GetMaxClip1");
	vSetupDetour(g_esGeneral.g_ddHitByVomitJarDetour, "MTDetour_CTerrorPlayer::OnHitByVomitJar");
	vSetupDetour(g_esGeneral.g_ddIncapacitatedAsTankDetour, "MTDetour_CTerrorPlayer::OnIncapacitatedAsTank");
	vSetupDetour(g_esGeneral.g_ddInitialContainedActionDetour, "MTDetour_TankBehavior::InitialContainedAction");
	vSetupDetour(g_esGeneral.g_ddITExpiredDetour, "MTDetour_CTerrorPlayer::OnITExpired");
	vSetupDetour(g_esGeneral.g_ddLadderDismountDetour, "MTDetour_CTerrorPlayer::OnLadderDismount");
	vSetupDetour(g_esGeneral.g_ddLadderMountDetour, "MTDetour_CTerrorPlayer::OnLadderMount");
	vSetupDetour(g_esGeneral.g_ddLauncherDirectionDetour, "MTDetour_CEnvRockLauncher::LaunchCurrentDir");
	vSetupDetour(g_esGeneral.g_ddLeaveStasisDetour, "MTDetour_Tank::LeaveStasis");
	vSetupDetour(g_esGeneral.g_ddMaxCarryDetour, "MTDetour_CAmmoDef::MaxCarry");
	vSetupDetour(g_esGeneral.g_ddPipeBombProjectileCreateDetour, "MTDetour_CPipeBombProjectile::Create");
	vSetupDetour(g_esGeneral.g_ddPreThinkDetour, "MTDetour_CTerrorPlayer::PreThink");
	vSetupDetour(g_esGeneral.g_ddReplaceTankDetour, "MTDetour_ZombieManager::ReplaceTank");
	vSetupDetour(g_esGeneral.g_ddRevivedDetour, "MTDetour_CTerrorPlayer::OnRevived");
	vSetupDetour(g_esGeneral.g_ddSecondaryAttackDetour, "MTDetour_CTerrorWeapon::SecondaryAttack");
	vSetupDetour(g_esGeneral.g_ddSecondaryAttackDetour2, "MTDetour_CTerrorMeleeWeapon::SecondaryAttack");
	vSetupDetour(g_esGeneral.g_ddSelectWeightedSequenceDetour, "MTDetour_CTerrorPlayer::SelectWeightedSequence");
	vSetupDetour(g_esGeneral.g_ddSetMainActivityDetour, "MTDetour_CTerrorPlayer::SetMainActivity");
	vSetupDetour(g_esGeneral.g_ddShovedByPounceLandingDetour, "MTDetour_CTerrorPlayer::OnShovedByPounceLanding");
	vSetupDetour(g_esGeneral.g_ddShovedBySurvivorDetour, "MTDetour_CTerrorPlayer::OnShovedBySurvivor");
	vSetupDetour(g_esGeneral.g_ddSpawnTankDetour, "MTDetour_ZombieManager::SpawnTank");
	vSetupDetour(g_esGeneral.g_ddStaggeredDetour, "MTDetour_CTerrorPlayer::OnStaggered");
	vSetupDetour(g_esGeneral.g_ddStartActionDetour, "MTDetour_CBaseBackpackItem::StartAction");
	vSetupDetour(g_esGeneral.g_ddStartHealingDetour, "MTDetour_CFirstAidKit::StartHealing");
	vSetupDetour(g_esGeneral.g_ddStartRevivingDetour, "MTDetour_CTerrorPlayer::StartReviving");
	vSetupDetour(g_esGeneral.g_ddTankClawDoSwingDetour, "MTDetour_CTankClaw::DoSwing");
	vSetupDetour(g_esGeneral.g_ddTankClawGroundPoundDetour, "MTDetour_CTankClaw::GroundPound");
	vSetupDetour(g_esGeneral.g_ddTankClawPlayerHitDetour, "MTDetour_CTankClaw::OnPlayerHit");
	vSetupDetour(g_esGeneral.g_ddTankClawPrimaryAttackDetour, "MTDetour_CTankClaw::PrimaryAttack");
	vSetupDetour(g_esGeneral.g_ddTankRockCreateDetour, "MTDetour_CTankRock::Create");
	vSetupDetour(g_esGeneral.g_ddTankRockDetonateDetour, "MTDetour_CTankRock::Detonate");
	vSetupDetour(g_esGeneral.g_ddTankRockReleaseDetour, "MTDetour_CTankRock::OnRelease");
	vSetupDetour(g_esGeneral.g_ddTestMeleeSwingCollisionDetour, "MTDetour_CTerrorMeleeWeapon::TestMeleeSwingCollision");
	vSetupDetour(g_esGeneral.g_ddThrowActivateAbilityDetour, "MTDetour_CThrow::ActivateAbility");
	vSetupDetour(g_esGeneral.g_ddUseDetour, "MTDetour_CTerrorGun::Use");
	vSetupDetour(g_esGeneral.g_ddUseDetour2, "MTDetour_CWeaponSpawn::Use");
	vSetupDetour(g_esGeneral.g_ddVomitedUponDetour, "MTDetour_CTerrorPlayer::OnVomitedUpon");
}

void vToggleDetour(DynamicDetour &detourHandle, const char[] name, HookMode mode, DHookCallback callback, bool toggle, int game = 0, bool override = false)
{
	int iIndex = iGetDetourIndex(name);
	if (detourHandle == null || (game == 1 && g_bSecondGame) || (game == 2 && !g_bSecondGame) || iIndex == -1 || (!toggle && !g_esDetour[iIndex].g_bInstalled))
	{
		return;
	}

	if (g_esDetour[iIndex].g_iType <= 3)
	{
		if (g_esDetour[iIndex].g_iType == 0 || (!override && g_esDetour[iIndex].g_iType < 3))
		{
			return;
		}
		else if (!override && g_esDetour[iIndex].g_iType == 3 && g_esDetour[iIndex].g_bBypassNeeded)
		{
			return;
		}
		else if (mode == Hook_Pre && (g_esDetour[iIndex].g_iPreHook == 0 || (!override && g_esDetour[iIndex].g_iPreHook == 1 && g_esDetour[iIndex].g_bBypassNeeded)))
		{
			return;
		}
		else if (mode == Hook_Post && (g_esDetour[iIndex].g_iPostHook == 0 || (!override && g_esDetour[iIndex].g_iPostHook == 1 && g_esDetour[iIndex].g_bBypassNeeded)))
		{
			return;
		}
	}

	bool bToggle = toggle ? detourHandle.Enable(mode, callback) : detourHandle.Disable(mode, callback);
	if (!bToggle)
	{
		LogError("%s Failed to %s the %s-hook detour for the \"%s\" function.", MT_TAG, (toggle ? "enable" : "disable"), ((mode == Hook_Pre) ? "pre" : "post"), name);

		return;
	}

	g_esDetour[iIndex].g_bInstalled = toggle;

	if (g_esDetour[iIndex].g_bLog)
	{
		vLogMessage(-1, _, "%s %sabled the \"%s\" %s-hook detour.", MT_TAG, (toggle ? "En" : "Dis"), name, ((mode == Hook_Pre) ? "pre" : "post"));
	}
}

void vToggleDetours(bool toggle)
{
	vToggleDetour(g_esGeneral.g_ddBaseEntityCreateDetour, "MTDetour_CBaseEntity::Create", Hook_Post, mreBaseEntityCreatePost, toggle, 1);
	vToggleDetour(g_esGeneral.g_ddFinishHealingDetour, "MTDetour_CFirstAidKit::FinishHealing", Hook_Pre, mreFinishHealingPre, toggle, 1);
	vToggleDetour(g_esGeneral.g_ddFinishHealingDetour, "MTDetour_CFirstAidKit::FinishHealing", Hook_Post, mreFinishHealingPost, toggle, 1);
	vToggleDetour(g_esGeneral.g_ddSetMainActivityDetour, "MTDetour_CTerrorPlayer::SetMainActivity", Hook_Pre, mreSetMainActivityPre, toggle, 1);

	vToggleDetour(g_esGeneral.g_ddActionCompleteDetour, "MTDetour_CFirstAidKit::OnActionComplete", Hook_Pre, mreActionCompletePre, toggle, 2);
	vToggleDetour(g_esGeneral.g_ddActionCompleteDetour, "MTDetour_CFirstAidKit::OnActionComplete", Hook_Post, mreActionCompletePost, toggle, 2);
	vToggleDetour(g_esGeneral.g_ddDoAnimationEventDetour, "MTDetour_CTerrorPlayer::DoAnimationEvent", Hook_Pre, mreDoAnimationEventPre, toggle, 2);
	vToggleDetour(g_esGeneral.g_ddFlingDetour, "MTDetour_CTerrorPlayer::Fling", Hook_Pre, mreFlingPre, toggle, 2);
	vToggleDetour(g_esGeneral.g_ddHitByVomitJarDetour, "MTDetour_CTerrorPlayer::OnHitByVomitJar", Hook_Pre, mreHitByVomitJarPre, toggle, 2);
	vToggleDetour(g_esGeneral.g_ddSecondaryAttackDetour2, "MTDetour_CTerrorMeleeWeapon::SecondaryAttack", Hook_Pre, mreSecondaryAttackPre, toggle, 2);
	vToggleDetour(g_esGeneral.g_ddSecondaryAttackDetour2, "MTDetour_CTerrorMeleeWeapon::SecondaryAttack", Hook_Post, mreSecondaryAttackPost, toggle, 2);
	vToggleDetour(g_esGeneral.g_ddSelectWeightedSequenceDetour, "MTDetour_CTerrorPlayer::SelectWeightedSequence", Hook_Pre, mreSelectWeightedSequencePre, toggle, 2);
	vToggleDetour(g_esGeneral.g_ddStartActionDetour, "MTDetour_CBaseBackpackItem::StartAction", Hook_Pre, mreStartActionPre, toggle, 2);
	vToggleDetour(g_esGeneral.g_ddStartActionDetour, "MTDetour_CBaseBackpackItem::StartAction", Hook_Post, mreStartActionPost, toggle, 2);
	vToggleDetour(g_esGeneral.g_ddTankRockCreateDetour, "MTDetour_CTankRock::Create", Hook_Post, mreTankRockCreatePost, toggle, 2);
	vToggleDetour(g_esGeneral.g_ddTestMeleeSwingCollisionDetour, "MTDetour_CTerrorMeleeWeapon::TestMeleeSwingCollision", Hook_Pre, mreTestMeleeSwingCollisionPre, toggle, 2);
	vToggleDetour(g_esGeneral.g_ddTestMeleeSwingCollisionDetour, "MTDetour_CTerrorMeleeWeapon::TestMeleeSwingCollision", Hook_Post, mreTestMeleeSwingCollisionPost, toggle, 2);

	vToggleDetour(g_esGeneral.g_ddBeginChangeLevelDetour, "MTDetour_CTerrorPlayer::OnBeginChangeLevel", Hook_Pre, mreBeginChangeLevelPre, toggle);
	vToggleDetour(g_esGeneral.g_ddCanDeployForDetour, "MTDetour_CTerrorWeapon::CanDeployFor", Hook_Pre, mreCanDeployForPre, toggle);
	vToggleDetour(g_esGeneral.g_ddCanDeployForDetour, "MTDetour_CTerrorWeapon::CanDeployFor", Hook_Post, mreCanDeployForPost, toggle);
	vToggleDetour(g_esGeneral.g_ddCheckJumpButtonDetour, "MTDetour_CTerrorGameMovement::CheckJumpButton", Hook_Pre, mreCheckJumpButtonPre, toggle);
	vToggleDetour(g_esGeneral.g_ddCheckJumpButtonDetour, "MTDetour_CTerrorGameMovement::CheckJumpButton", Hook_Post, mreCheckJumpButtonPost, toggle);
	vToggleDetour(g_esGeneral.g_ddDeathFallCameraEnableDetour, "MTDetour_CDeathFallCamera::Enable", Hook_Pre, mreDeathFallCameraEnablePre, toggle);
	vToggleDetour(g_esGeneral.g_ddDoJumpDetour, "MTDetour_CTerrorGameMovement::DoJump", Hook_Pre, mreDoJumpPre, toggle);
	vToggleDetour(g_esGeneral.g_ddDoJumpDetour, "MTDetour_CTerrorGameMovement::DoJump", Hook_Post, mreDoJumpPost, toggle);
	vToggleDetour(g_esGeneral.g_ddEnterGhostStateDetour, "MTDetour_CTerrorPlayer::OnEnterGhostState", Hook_Post, mreEnterGhostStatePost, toggle);
	vToggleDetour(g_esGeneral.g_ddEnterStasisDetour, "MTDetour_Tank::EnterStasis", Hook_Post, mreEnterStasisPost, toggle);
	vToggleDetour(g_esGeneral.g_ddEventKilledDetour, "MTDetour_CTerrorPlayer::Event_Killed", Hook_Pre, mreEventKilledPre, toggle);
	vToggleDetour(g_esGeneral.g_ddEventKilledDetour, "MTDetour_CTerrorPlayer::Event_Killed", Hook_Post, mreEventKilledPost, toggle);
	vToggleDetour(g_esGeneral.g_ddExtinguishDetour, "MTDetour_CTerrorPlayer::Extinguish", Hook_Pre, mreExtinguishPre, toggle);
	vToggleDetour(g_esGeneral.g_ddFallingDetour, "MTDetour_CTerrorPlayer::OnFalling", Hook_Pre, mreFallingPre, toggle);
	vToggleDetour(g_esGeneral.g_ddFallingDetour, "MTDetour_CTerrorPlayer::OnFalling", Hook_Post, mreFallingPost, toggle);
	vToggleDetour(g_esGeneral.g_ddFireBulletDetour, "MTDetour_CTerrorGun::FireBullet", Hook_Pre, mreFireBulletPre, toggle);
	vToggleDetour(g_esGeneral.g_ddFireBulletDetour, "MTDetour_CTerrorGun::FireBullet", Hook_Post, mreFireBulletPost, toggle);
	vToggleDetour(g_esGeneral.g_ddFirstSurvivorLeftSafeAreaDetour, "MTDetour_CDirector::OnFirstSurvivorLeftSafeArea", Hook_Post, mreFirstSurvivorLeftSafeAreaPost, toggle);
	vToggleDetour(g_esGeneral.g_ddGetMaxClip1Detour, "MTDetour_CBaseCombatWeapon::GetMaxClip1", Hook_Pre, mreGetMaxClip1Pre, toggle);
	vToggleDetour(g_esGeneral.g_ddIncapacitatedAsTankDetour, "MTDetour_CTerrorPlayer::OnIncapacitatedAsTank", Hook_Pre, mreIncapacitatedAsTankPre, toggle);
	vToggleDetour(g_esGeneral.g_ddIncapacitatedAsTankDetour, "MTDetour_CTerrorPlayer::OnIncapacitatedAsTank", Hook_Post, mreIncapacitatedAsTankPost, toggle);
	vToggleDetour(g_esGeneral.g_ddInitialContainedActionDetour, "MTDetour_TankBehavior::InitialContainedAction", Hook_Pre, mreInitialContainedActionPre, toggle);
	vToggleDetour(g_esGeneral.g_ddInitialContainedActionDetour, "MTDetour_TankBehavior::InitialContainedAction", Hook_Post, mreInitialContainedActionPost, toggle);
	vToggleDetour(g_esGeneral.g_ddITExpiredDetour, "MTDetour_CTerrorPlayer::OnITExpired", Hook_Post, mreITExpiredPost, toggle);
	vToggleDetour(g_esGeneral.g_ddLadderDismountDetour, "MTDetour_CTerrorPlayer::OnLadderDismount", Hook_Pre, mreLadderDismountPre, toggle);
	vToggleDetour(g_esGeneral.g_ddLadderDismountDetour, "MTDetour_CTerrorPlayer::OnLadderDismount", Hook_Post, mreLadderDismountPost, toggle);
	vToggleDetour(g_esGeneral.g_ddLadderMountDetour, "MTDetour_CTerrorPlayer::OnLadderMount", Hook_Pre, mreLadderMountPre, toggle);
	vToggleDetour(g_esGeneral.g_ddLadderMountDetour, "MTDetour_CTerrorPlayer::OnLadderMount", Hook_Post, mreLadderMountPost, toggle);
	vToggleDetour(g_esGeneral.g_ddLauncherDirectionDetour, "MTDetour_CEnvRockLauncher::LaunchCurrentDir", Hook_Pre, mreLaunchDirectionPre, toggle);
	vToggleDetour(g_esGeneral.g_ddLeaveStasisDetour, "MTDetour_Tank::LeaveStasis", Hook_Post, mreLeaveStasisPost, toggle);
	vToggleDetour(g_esGeneral.g_ddMaxCarryDetour, "MTDetour_CAmmoDef::MaxCarry", Hook_Pre, mreMaxCarryPre, toggle);
	vToggleDetour(g_esGeneral.g_ddPipeBombProjectileCreateDetour, "MTDetour_CPipeBombProjectile::Create", Hook_Pre, mrePipeBombProjectileCreatePre, toggle);
	vToggleDetour(g_esGeneral.g_ddPipeBombProjectileCreateDetour, "MTDetour_CPipeBombProjectile::Create", Hook_Post, mrePipeBombProjectileCreatePost, toggle);
	vToggleDetour(g_esGeneral.g_ddPreThinkDetour, "MTDetour_CTerrorPlayer::PreThink", Hook_Pre, mrePreThinkPre, toggle);
	vToggleDetour(g_esGeneral.g_ddPreThinkDetour, "MTDetour_CTerrorPlayer::PreThink", Hook_Post, mrePreThinkPost, toggle);
	vToggleDetour(g_esGeneral.g_ddReplaceTankDetour, "MTDetour_ZombieManager::ReplaceTank", Hook_Post, mreReplaceTankPost, toggle);
	vToggleDetour(g_esGeneral.g_ddRevivedDetour, "MTDetour_CTerrorPlayer::OnRevived", Hook_Pre, mreRevivedPre, toggle);
	vToggleDetour(g_esGeneral.g_ddRevivedDetour, "MTDetour_CTerrorPlayer::OnRevived", Hook_Post, mreRevivedPost, toggle);
	vToggleDetour(g_esGeneral.g_ddSecondaryAttackDetour, "MTDetour_CTerrorWeapon::SecondaryAttack", Hook_Pre, mreSecondaryAttackPre, toggle);
	vToggleDetour(g_esGeneral.g_ddSecondaryAttackDetour, "MTDetour_CTerrorWeapon::SecondaryAttack", Hook_Post, mreSecondaryAttackPost, toggle);
	vToggleDetour(g_esGeneral.g_ddShovedByPounceLandingDetour, "MTDetour_CTerrorPlayer::OnShovedByPounceLanding", Hook_Pre, mreShovedByPounceLandingPre, toggle);
	vToggleDetour(g_esGeneral.g_ddShovedBySurvivorDetour, "MTDetour_CTerrorPlayer::OnShovedBySurvivor", Hook_Pre, mreShovedBySurvivorPre, toggle);
	vToggleDetour(g_esGeneral.g_ddSpawnTankDetour, "MTDetour_ZombieManager::SpawnTank", Hook_Pre, mreSpawnTankPre, toggle);
	vToggleDetour(g_esGeneral.g_ddStaggeredDetour, "MTDetour_CTerrorPlayer::OnStaggered", Hook_Pre, mreStaggeredPre, toggle);
	vToggleDetour(g_esGeneral.g_ddStartRevivingDetour, "MTDetour_CTerrorPlayer::StartReviving", Hook_Pre, mreStartRevivingPre, toggle);
	vToggleDetour(g_esGeneral.g_ddStartRevivingDetour, "MTDetour_CTerrorPlayer::StartReviving", Hook_Post, mreStartRevivingPost, toggle);
	vToggleDetour(g_esGeneral.g_ddTankClawDoSwingDetour, "MTDetour_CTankClaw::DoSwing", Hook_Pre, mreTankClawDoSwingPre, toggle);
	vToggleDetour(g_esGeneral.g_ddTankClawDoSwingDetour, "MTDetour_CTankClaw::DoSwing", Hook_Post, mreTankClawDoSwingPost, toggle);
	vToggleDetour(g_esGeneral.g_ddTankClawGroundPoundDetour, "MTDetour_CTankClaw::GroundPound", Hook_Pre, mreTankClawGroundPoundPre, toggle);
	vToggleDetour(g_esGeneral.g_ddTankClawGroundPoundDetour, "MTDetour_CTankClaw::GroundPound", Hook_Post, mreTankClawGroundPoundPost, toggle);
	vToggleDetour(g_esGeneral.g_ddTankClawPlayerHitDetour, "MTDetour_CTankClaw::OnPlayerHit", Hook_Pre, mreTankClawPlayerHitPre, toggle);
	vToggleDetour(g_esGeneral.g_ddTankClawPlayerHitDetour, "MTDetour_CTankClaw::OnPlayerHit", Hook_Post, mreTankClawPlayerHitPost, toggle);
	vToggleDetour(g_esGeneral.g_ddTankClawPrimaryAttackDetour, "MTDetour_CTankClaw::PrimaryAttack", Hook_Pre, mreTankClawPrimaryAttackPre, toggle);
	vToggleDetour(g_esGeneral.g_ddTankRockDetonateDetour, "MTDetour_CTankRock::Detonate", Hook_Pre, mreTankRockDetonatePre, toggle);
	vToggleDetour(g_esGeneral.g_ddThrowActivateAbilityDetour, "MTDetour_CThrow::ActivateAbility", Hook_Pre, mreThrowActivateAbilityPre, toggle);
	vToggleDetour(g_esGeneral.g_ddUseDetour, "MTDetour_CTerrorGun::Use", Hook_Pre, mreUsePre, toggle);
	vToggleDetour(g_esGeneral.g_ddUseDetour, "MTDetour_CTerrorGun::Use", Hook_Post, mreUsePost, toggle);
	vToggleDetour(g_esGeneral.g_ddUseDetour2, "MTDetour_CWeaponSpawn::Use", Hook_Pre, mreUsePre, toggle);
	vToggleDetour(g_esGeneral.g_ddUseDetour2, "MTDetour_CWeaponSpawn::Use", Hook_Post, mreUsePost, toggle);
	vToggleDetour(g_esGeneral.g_ddVomitedUponDetour, "MTDetour_CTerrorPlayer::OnVomitedUpon", Hook_Pre, mreVomitedUponPre, toggle);
	vToggleDetour(g_esGeneral.g_ddVomitedUponDetour, "MTDetour_CTerrorPlayer::OnVomitedUpon", Hook_Post, mreVomitedUponPost, toggle);

	switch (g_esGeneral.g_iPlatformType == 2)
	{
		case true:
		{
			vToggleDetour(g_esGeneral.g_ddStartHealingDetour, "MTDetour_CFirstAidKit::StartHealing", Hook_Pre, mreStartHealingLinuxPre, toggle, 1);
			vToggleDetour(g_esGeneral.g_ddStartHealingDetour, "MTDetour_CFirstAidKit::StartHealing", Hook_Post, mreStartHealingLinuxPost, toggle, 1);

			if (!g_bSecondGame)
			{
				vToggleDetour(g_esGeneral.g_ddTankRockReleaseDetour, "MTDetour_CTankRock::OnRelease", Hook_Pre, mreTankRockReleaseLinuxPre, toggle);
				vToggleDetour(g_esGeneral.g_ddTankRockReleaseDetour, "MTDetour_CTankRock::OnRelease", Hook_Post, mreTankRockReleaseLinuxPost, toggle);
			}
			else
			{
				vToggleDetour(g_esGeneral.g_ddTankRockReleaseDetour, "MTDetour_CTankRock::OnRelease", Hook_Pre, mreTankRockReleaseWindowsPre, toggle);
				vToggleDetour(g_esGeneral.g_ddTankRockReleaseDetour, "MTDetour_CTankRock::OnRelease", Hook_Post, mreTankRockReleaseWindowsPost, toggle);
			}
		}
		case false:
		{
			vToggleDetour(g_esGeneral.g_ddStartHealingDetour, "MTDetour_CFirstAidKit::StartHealing", Hook_Pre, mreStartHealingWindowsPre, toggle, 1);
			vToggleDetour(g_esGeneral.g_ddStartHealingDetour, "MTDetour_CFirstAidKit::StartHealing", Hook_Post, mreStartHealingWindowsPost, toggle, 1);
			vToggleDetour(g_esGeneral.g_ddTankRockReleaseDetour, "MTDetour_CTankRock::OnRelease", Hook_Pre, mreTankRockReleaseWindowsPre, toggle);
			vToggleDetour(g_esGeneral.g_ddTankRockReleaseDetour, "MTDetour_CTankRock::OnRelease", Hook_Post, mreTankRockReleaseWindowsPost, toggle);
		}
	}
}

int iGetDetourIndex(const char[] name)
{
	for (int iPos = 0; iPos < g_esGeneral.g_iDetourCount; iPos++)
	{
		if (StrEqual(name, g_esDetour[iPos].g_sName))
		{
			return iPos;
		}
	}

	return -1;
}

/**
 * DHooks Detour callbacks
 **/

MRESReturn mreActionCompletePre(int pThis, DHookParam hParams)
{
	if (g_esGeneral.g_cvMTFirstAidHealPercent != null)
	{
		int iSurvivor = hParams.IsNull(1) ? 0 : hParams.Get(1), iTeammate = hParams.IsNull(2) ? 0 : hParams.Get(2);
		if (bIsSurvivor(iSurvivor) && (bIsDeveloper(iSurvivor, 6) || (g_esPlayer[iSurvivor].g_iRewardTypes & MT_REWARD_HEALTH)))
		{
			vSetHealPercentCvar(false, iSurvivor);
		}
		else if (bIsSurvivor(iTeammate) && (bIsDeveloper(iTeammate, 6) || (g_esPlayer[iTeammate].g_iRewardTypes & MT_REWARD_HEALTH)))
		{
			vSetHealPercentCvar(false, iTeammate);
		}
	}

	return MRES_Ignored;
}

MRESReturn mreActionCompletePost(int pThis, DHookParam hParams)
{
	if (g_esGeneral.g_flDefaultFirstAidHealPercent != -1.0)
	{
		vSetHealPercentCvar(true);
	}

	return MRES_Ignored;
}

MRESReturn mreBaseEntityCreatePost(DHookReturn hReturn, DHookParam hParams)
{
	char sClassname[32];
	hParams.GetString(1, sClassname, sizeof sClassname);
	if (StrEqual(sClassname, "tank_rock") && hParams.IsNull(4))
	{
		vSetRockColor(hReturn.Value);
	}

	return MRES_Ignored;
}

MRESReturn mreBaseEntityGetGroundEntityPre(int pThis, DHookReturn hReturn)
{
	if (bIsSurvivor(pThis) && !bIsSurvivorDisabled(pThis) && !bIsSurvivorCaught(pThis) && iGetPlayerWaterLevel(pThis) < MT_WATER_WAIST)
	{
		float flCurrentTime = GetGameTime();
		if ((g_esPlayer[pThis].g_flLastJumpTime + MT_JUMP_DASHCOOLDOWN) > flCurrentTime)
		{
			g_esPlayer[pThis].g_bReleasedJump = false;

			return MRES_Ignored;
		}

		int iLimit = (bIsDeveloper(pThis, 5) && g_esDeveloper[pThis].g_iDevMidairDashes > g_esPlayer[pThis].g_iMidairDashesLimit) ? g_esDeveloper[pThis].g_iDevMidairDashes : g_esPlayer[pThis].g_iMidairDashesLimit;
		if (g_esPlayer[pThis].g_iMidairDashesCount < (iLimit + 1))
		{
			g_esPlayer[pThis].g_flLastJumpTime = flCurrentTime;
			g_esPlayer[pThis].g_iMidairDashesCount++;

			hReturn.Value = pThis;

			return MRES_Override;
		}
	}

	return MRES_Ignored;
}

MRESReturn mreBeginChangeLevelPre(int pThis, DHookParam hParams)
{
	if (bIsSurvivor(pThis) && g_esPlayer[pThis].g_iRewardTypes > 0)
	{
		vEndRewards(pThis, true);
	}

	return MRES_Ignored;
}

MRESReturn mreCanDeployForPre(int pThis, DHookReturn hReturn, DHookParam hParams)
{
	int iSurvivor = 0;

	switch (g_bSecondGame && !hParams.IsNull(1))
	{
		case true: iSurvivor = hParams.Get(1);
		case false: iSurvivor = !bIsValidEntity(pThis) ? 0 : GetEntPropEnt(pThis, Prop_Send, "m_hOwner");
	}

	if (bIsSurvivor(iSurvivor) && (bIsDeveloper(iSurvivor, 6) || ((g_esPlayer[iSurvivor].g_iRewardTypes & MT_REWARD_ATTACKBOOST) && g_esPlayer[iSurvivor].g_iLadderActions == 1)))
	{
		static int iIndex = -1;
		if (iIndex == -1)
		{
			iIndex = iGetPatchIndex("MTPatch_LadderMount2");
		}

		if (iIndex != -1)
		{
			vInstallPatch(iIndex);
		}
	}

	return MRES_Ignored;
}

MRESReturn mreCanDeployForPost(int pThis, DHookReturn hReturn, DHookParam hParams)
{
	static int iIndex = -1;
	if (iIndex == -1)
	{
		iIndex = iGetPatchIndex("MTPatch_LadderMount2");
	}

	if (iIndex != -1)
	{
		vRemovePatch(iIndex);
	}

	return MRES_Ignored;
}

MRESReturn mreCheckJumpButtonPre(Address pThis, DHookReturn hReturn)
{
	vToggleDetour(g_esGeneral.g_ddBaseEntityGetGroundEntityDetour, "MTDetour_CBaseEntity::GetGroundEntity", Hook_Pre, mreBaseEntityGetGroundEntityPre, true);

	return MRES_Ignored;
}

MRESReturn mreCheckJumpButtonPost(Address pThis, DHookReturn hReturn)
{
	vToggleDetour(g_esGeneral.g_ddBaseEntityGetGroundEntityDetour, "MTDetour_CBaseEntity::GetGroundEntity", Hook_Pre, mreBaseEntityGetGroundEntityPre, false);

	return MRES_Ignored;
}

MRESReturn mreDeathFallCameraEnablePre(int pThis, DHookParam hParams)
{
	int iSurvivor = hParams.IsNull(1) ? 0 : hParams.Get(1);
	if (bIsSurvivor(iSurvivor) && (bIsDeveloper(iSurvivor, 5) || bIsDeveloper(iSurvivor, 11) || (g_esPlayer[iSurvivor].g_iRewardTypes & MT_REWARD_SPEEDBOOST) || (g_esPlayer[iSurvivor].g_iRewardTypes & MT_REWARD_GODMODE)) && g_esPlayer[iSurvivor].g_bFalling)
	{
		g_esPlayer[iSurvivor].g_bFatalFalling = true;

		return MRES_Supercede;
	}

	g_esPlayer[iSurvivor].g_bFatalFalling = true;

	Action aResult = Plugin_Continue;
	Call_StartForward(g_esGeneral.g_gfFatalFallingForward);
	Call_PushCell(iSurvivor);
	Call_Finish(aResult);

	return (aResult == Plugin_Handled) ? MRES_Supercede : MRES_Ignored;
}

MRESReturn mreDoAnimationEventPre(int pThis, DHookParam hParams)
{
	if (bIsSurvivor(pThis) && (bIsDeveloper(pThis, 6) || (g_esPlayer[pThis].g_iRewardTypes & MT_REWARD_ATTACKBOOST)))
	{
		int iAnim = hParams.Get(1);
		if (iAnim == MT_ANIM_TANKPUNCHED || iAnim == MT_ANIM_LANDING)
		{
			hParams.Set(1, MT_ANIM_ACTIVESTATE);

			return MRES_ChangedHandled;
		}
	}

	return MRES_Ignored;
}

MRESReturn mreDoJumpPre(Address pThis, DHookParam hParams)
{
	Address adSurvivor = LoadFromAddress((pThis + view_as<Address>(4)), NumberType_Int32);
	int iSurvivor = iGetEntityIndex(iGetRefEHandle(adSurvivor));
	if (bIsSurvivor(iSurvivor))
	{
		bool bDeveloper = bIsDeveloper(iSurvivor, 5);
		if (bDeveloper || (g_esPlayer[iSurvivor].g_iRewardTypes & MT_REWARD_SPEEDBOOST))
		{
			if (!g_esGeneral.g_bPatchJumpHeight)
			{
				float flHeight = (bDeveloper && g_esDeveloper[iSurvivor].g_flDevJumpHeight > g_esPlayer[iSurvivor].g_flJumpHeight) ? g_esDeveloper[iSurvivor].g_flDevJumpHeight : g_esPlayer[iSurvivor].g_flJumpHeight;
				if (flHeight > 0.0)
				{
					g_esGeneral.g_bPatchJumpHeight = true;

					switch (!g_bSecondGame && g_esGeneral.g_iPlatformType == 2)
					{
						case true:
						{
							g_esGeneral.g_adOriginalJumpHeight[0] = LoadFromAddress(g_esGeneral.g_adDoJumpValue, NumberType_Int32);
							StoreToAddress(g_esGeneral.g_adDoJumpValue, view_as<int>(flHeight), NumberType_Int32, g_esGeneral.g_bUpdateDoJumpMemAccess);
							g_esGeneral.g_bUpdateDoJumpMemAccess = false;
						}
						case false:
						{
							g_esGeneral.g_adOriginalJumpHeight[1] = LoadFromAddress(g_esGeneral.g_adDoJumpValue, NumberType_Int32);
							g_esGeneral.g_adOriginalJumpHeight[0] = LoadFromAddress((g_esGeneral.g_adDoJumpValue + view_as<Address>(4)), NumberType_Int32);

							int iDouble[2];
							vGetDoubleFromFloat(flHeight, iDouble);
							StoreToAddress(g_esGeneral.g_adDoJumpValue, iDouble[1], NumberType_Int32, g_esGeneral.g_bUpdateDoJumpMemAccess);
							StoreToAddress((g_esGeneral.g_adDoJumpValue + view_as<Address>(4)), iDouble[0], NumberType_Int32, g_esGeneral.g_bUpdateDoJumpMemAccess);

							g_esGeneral.g_bUpdateDoJumpMemAccess = false;
						}
					}
				}
			}
		}
	}

	return MRES_Ignored;
}

MRESReturn mreDoJumpPost(Address pThis, DHookParam hParams)
{
	if (g_esGeneral.g_bPatchJumpHeight)
	{
		g_esGeneral.g_bPatchJumpHeight = false;

		switch (!g_bSecondGame && g_esGeneral.g_iPlatformType > 0)
		{
			case true: StoreToAddress(g_esGeneral.g_adDoJumpValue, g_esGeneral.g_adOriginalJumpHeight[0], NumberType_Int32, g_esGeneral.g_bUpdateDoJumpMemAccess);
			case false:
			{
				StoreToAddress(g_esGeneral.g_adDoJumpValue, g_esGeneral.g_adOriginalJumpHeight[1], NumberType_Int32, g_esGeneral.g_bUpdateDoJumpMemAccess);
				StoreToAddress((g_esGeneral.g_adDoJumpValue + view_as<Address>(4)), g_esGeneral.g_adOriginalJumpHeight[0], NumberType_Int32, g_esGeneral.g_bUpdateDoJumpMemAccess);
			}
		}
	}

	return MRES_Ignored;
}

MRESReturn mreEnterGhostStatePost(int pThis)
{
	if (bIsTank(pThis))
	{
		g_esPlayer[pThis].g_bKeepCurrentType = true;

		if (bIsCoopMode() && g_esGeneral.g_flForceSpawn > 0.0)
		{
			CreateTimer(g_esGeneral.g_flForceSpawn, tTimerForceSpawnTank, GetClientUserId(pThis), TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
		}
	}

	return MRES_Ignored;
}

MRESReturn mreEnterStasisPost(int pThis)
{
	if (bIsTank(pThis))
	{
		g_esPlayer[pThis].g_bStasis = true;
	}

	return MRES_Ignored;
}

MRESReturn mreEventKilledPre(int pThis, DHookParam hParams)
{
	int iAttacker = hParams.GetObjectVar(1, g_esGeneral.g_iAttackerOffset, ObjectValueType_Ehandle);
	if (bIsSurvivor(pThis, MT_CHECK_INDEX|MT_CHECK_INGAME))
	{
		g_esPlayer[pThis].g_bLastLife = false;
		g_esPlayer[pThis].g_iReviveCount = 0;

		vResetSurvivorStats(pThis, true);
		vSaveSurvivorWeapons(pThis);
	}
	else if (bIsTank(pThis, MT_CHECK_INDEX|MT_CHECK_INGAME))
	{
		if (!bIsCustomTank(pThis))
		{
			g_esGeneral.g_iTankCount--;

			if (!g_esPlayer[pThis].g_bArtificial)
			{
				delete g_esGeneral.g_hTankWaveTimer;

				g_esGeneral.g_hTankWaveTimer = CreateTimer(5.0, tTimerTankWave);
			}
		}

		if (bIsTankSupported(pThis) && bIsCustomTankSupported(pThis))
		{
			vCombineAbilitiesForward(pThis, MT_COMBO_UPONDEATH);
		}
	}
	else if (bIsSpecialInfected(pThis, MT_CHECK_INDEX|MT_CHECK_INGAME))
	{
		SetEntityRenderMode(pThis, RENDER_NORMAL);
		SetEntityRenderColor(pThis, 255, 255, 255, 255);

		if (bIsSurvivor(iAttacker) && (bIsDeveloper(iAttacker, 10) || ((g_esPlayer[iAttacker].g_iRewardTypes & MT_REWARD_GODMODE) && g_esPlayer[iAttacker].g_iCleanKills == 1)))
		{
			bool bBoomer = bIsBoomer(pThis, MT_CHECK_INDEX|MT_CHECK_INGAME), bSmoker = bIsSmoker(pThis, MT_CHECK_INDEX|MT_CHECK_INGAME);
			char sName[32];
			static int iIndex[11] = {-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1};
			int iLimit = g_bSecondGame ? 6 : 3;
			for (int iPos = 0; iPos < (sizeof iIndex); iPos++)
			{
				if (bBoomer && iPos < iLimit)
				{
					FormatEx(sName, sizeof sName, "MTPatch_Boomer%iCleanKill", (iPos + 1));
					if (iIndex[iPos] == -1)
					{
						iIndex[iPos] = iGetPatchIndex(sName);
					}

					if (iIndex[iPos] != -1)
					{
						vInstallPatch(iIndex[iPos]);
					}
				}
				else if (bSmoker && iLimit <= iPos <= (iLimit + 3))
				{
					FormatEx(sName, sizeof sName, "MTPatch_Smoker%iCleanKill", (iPos - (iLimit - 1)));
					if (iIndex[iPos] == -1)
					{
						iIndex[iPos] = iGetPatchIndex(sName);
					}

					if (iIndex[iPos] != -1)
					{
						vInstallPatch(iIndex[iPos]);
					}
				}
			}

			if (bIsSpitter(pThis, MT_CHECK_INDEX|MT_CHECK_INGAME))
			{
				if (iIndex[10] == -1)
				{
					iIndex[10] = iGetPatchIndex("MTPatch_SpitterCleanKill");
				}

				if (iIndex[10] != -1)
				{
					vInstallPatch(iIndex[10]);
				}
			}
		}
	}

	Call_StartForward(g_esGeneral.g_gfPlayerEventKilledForward);
	Call_PushCell(pThis);
	Call_PushCell(iAttacker);
	Call_Finish();

	return MRES_Ignored;
}

MRESReturn mreEventKilledPost(int pThis, DHookParam hParams)
{
	char sName[32];
	static int iIndex[11] = {-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1};
	int iLimit = g_bSecondGame ? 6 : 3;
	for (int iPos = 0; iPos < (sizeof iIndex); iPos++)
	{
		if (iPos < iLimit)
		{
			FormatEx(sName, sizeof sName, "MTPatch_Boomer%iCleanKill", (iPos + 1));
			if (iIndex[iPos] == -1)
			{
				iIndex[iPos] = iGetPatchIndex(sName);
			}

			if (iIndex[iPos] != -1)
			{
				vRemovePatch(iIndex[iPos]);
			}
		}
		else if (iLimit <= iPos <= (iLimit + 3))
		{
			FormatEx(sName, sizeof sName, "MTPatch_Smoker%iCleanKill", (iPos - (iLimit - 1)));
			if (iIndex[iPos] == -1)
			{
				iIndex[iPos] = iGetPatchIndex(sName);
			}

			if (iIndex[iPos] != -1)
			{
				vRemovePatch(iIndex[iPos]);
			}
		}
	}

	if (iIndex[10] == -1)
	{
		iIndex[10] = iGetPatchIndex("MTPatch_SpitterCleanKill");
	}

	if (iIndex[10] != -1)
	{
		vRemovePatch(iIndex[10]);
	}

	return MRES_Ignored;
}

MRESReturn mreExtinguishPre(int pThis)
{
	if (bIsInfected(pThis))
	{
		int iSurvivor = g_esPlayer[pThis].g_iLastFireAttacker;
		if (bIsSurvivor(iSurvivor) && (bIsDeveloper(iSurvivor, 7) || ((g_esPlayer[iSurvivor].g_iRewardTypes & MT_REWARD_DAMAGEBOOST) && g_esPlayer[iSurvivor].g_iInextinguishableFire == 1)))
		{
			return MRES_Supercede;
		}
	}

	return MRES_Ignored;
}

MRESReturn mreFallingPre(int pThis)
{
	if (bIsSurvivor(pThis) && !g_esPlayer[pThis].g_bFalling)
	{
		g_esPlayer[pThis].g_bFallDamage = true;
		g_esPlayer[pThis].g_bFalling = true;

		static int iIndex[2] = {-1, -1};
		if (iIndex[0] == -1)
		{
			iIndex[0] = iGetPatchIndex("MTPatch_DoJumpHeight");
		}

		if (((iIndex[0] != -1 && g_esPatch[iIndex[0]].g_iType == 2) || bIsDeveloper(pThis, 5) || bIsDeveloper(pThis, 11) || (g_esPlayer[pThis].g_iRewardTypes & MT_REWARD_SPEEDBOOST) || (g_esPlayer[pThis].g_iRewardTypes & MT_REWARD_GODMODE)) && !g_esGeneral.g_bPatchFallingSound)
		{
			g_esGeneral.g_bPatchFallingSound = true;

			if (iIndex[1] == -1)
			{
				iIndex[1] = iGetPatchIndex("MTPatch_FallScreamMute");
			}

			if (iIndex[1] != -1)
			{
				vInstallPatch(iIndex[1]);
			}

			char sVoiceLine[64];
			sVoiceLine = (bIsDeveloper(pThis) && g_esDeveloper[pThis].g_sDevFallVoiceline[0] != '\0') ? g_esDeveloper[pThis].g_sDevFallVoiceline : g_esPlayer[pThis].g_sFallVoiceline;
			if (sVoiceLine[0] != '\0')
			{
				vForceVocalize(pThis, sVoiceLine);
			}
		}
	}

	return MRES_Ignored;
}

MRESReturn mreFallingPost(int pThis)
{
	if (g_esGeneral.g_bPatchFallingSound)
	{
		g_esGeneral.g_bPatchFallingSound = false;

		static int iIndex = -1;
		if (iIndex == -1)
		{
			iIndex = iGetPatchIndex("MTPatch_FallScreamMute");
		}

		if (iIndex != -1)
		{
			vRemovePatch(iIndex);
		}
	}

	return MRES_Ignored;
}

MRESReturn mreFirstSurvivorLeftSafeAreaPost(DHookParam hParams)
{
	int iSurvivor = hParams.IsNull(1) ? 0 : hParams.Get(1);
	if (bIsSurvivor(iSurvivor))
	{
		vResetTimers(true);
	}

	return MRES_Ignored;
}

MRESReturn mreFinishHealingPre(int pThis)
{
	int iSurvivor = !bIsValidEntity(pThis) ? 0 : GetEntPropEnt(pThis, Prop_Send, "m_hOwner");
	if (bIsSurvivor(iSurvivor) && g_esGeneral.g_cvMTFirstAidHealPercent != null)
	{
		if (bIsDeveloper(iSurvivor, 6) || (g_esPlayer[iSurvivor].g_iRewardTypes & MT_REWARD_HEALTH))
		{
			vSetHealPercentCvar(false, iSurvivor);
		}
	}

	return MRES_Ignored;
}

MRESReturn mreFinishHealingPost(int pThis)
{
	if (g_esGeneral.g_flDefaultFirstAidHealPercent != -1.0)
	{
		vSetHealPercentCvar(true);
	}

	return MRES_Ignored;
}

MRESReturn mreFireBulletPre(int pThis)
{
	int iSurvivor = !bIsValidEntity(pThis) ? 0 : GetEntPropEnt(pThis, Prop_Send, "m_hOwner");
	if (bIsSurvivor(iSurvivor))
	{
		if ((bIsDeveloper(iSurvivor, 4) || ((g_esPlayer[iSurvivor].g_iRewardTypes & MT_REWARD_DAMAGEBOOST) && g_esPlayer[iSurvivor].g_iRecoilDampener == 1)) && !g_esGeneral.g_bPatchVerticalPunch)
		{
			g_esGeneral.g_bPatchVerticalPunch = true;

			int iWeapon = iGetWeaponInfoID(pThis);
			if (iWeapon != -1)
			{
				Address adWeapon = view_as<Address>(iWeapon + g_esGeneral.g_iVerticalPunchOffset);
				g_esGeneral.g_adOriginalVerticalPunch = LoadFromAddress(adWeapon, NumberType_Int32);
				StoreToAddress(adWeapon, 0.0, NumberType_Int32, g_esGeneral.g_bUpdateWeaponInfoMemAccess);
				g_esGeneral.g_bUpdateWeaponInfoMemAccess = false;
			}
		}

		if (g_bSecondGame && (bIsDeveloper(iSurvivor, 9) || ((g_esPlayer[iSurvivor].g_iRewardTypes & MT_REWARD_DAMAGEBOOST) && g_esPlayer[iSurvivor].g_iSledgehammerRounds == 1)) && g_esGeneral.g_cvMTPhysicsPushScale != null)
		{
			g_esGeneral.g_flDefaultPhysicsPushScale = g_esGeneral.g_cvMTPhysicsPushScale.FloatValue;
			g_esGeneral.g_cvMTPhysicsPushScale.FloatValue = 5.0;
		}
	}

	return MRES_Ignored;
}

MRESReturn mreFireBulletPost(int pThis)
{
	if (g_esGeneral.g_bPatchVerticalPunch)
	{
		g_esGeneral.g_bPatchVerticalPunch = false;

		int iWeapon = iGetWeaponInfoID(pThis);
		if (iWeapon != -1)
		{
			StoreToAddress(view_as<Address>(iWeapon + g_esGeneral.g_iVerticalPunchOffset), g_esGeneral.g_adOriginalVerticalPunch, NumberType_Int32, g_esGeneral.g_bUpdateWeaponInfoMemAccess);
		}
	}

	if (g_esGeneral.g_flDefaultPhysicsPushScale != -1.0)
	{
		g_esGeneral.g_cvMTPhysicsPushScale.FloatValue = g_esGeneral.g_flDefaultPhysicsPushScale;
		g_esGeneral.g_flDefaultPhysicsPushScale = -1.0;
	}

	return MRES_Ignored;
}

MRESReturn mreFlingPre(int pThis, DHookParam hParams)
{
	if (bIsSurvivor(pThis))
	{
		if (bIsDeveloper(pThis, 6) || (g_esPlayer[pThis].g_iRewardTypes & MT_REWARD_ATTACKBOOST))
		{
			hParams.Set(4, 1.5);

			return MRES_ChangedHandled;
		}
		else if (bIsDeveloper(pThis, 8) || (g_esPlayer[pThis].g_iRewardTypes & MT_REWARD_GODMODE))
		{
			return MRES_Supercede;
		}
	}

	return MRES_Ignored;
}

MRESReturn mreGetMaxClip1Pre(int pThis, DHookReturn hReturn)
{
	int iSurvivor = !bIsValidEntity(pThis) ? 0 : GetEntPropEnt(pThis, Prop_Send, "m_hOwner"), iClip = iGetMaxAmmo(iSurvivor, 0, pThis, false);
	if (bIsSurvivor(iSurvivor) && iClip > 0)
	{
		bool bDeveloper = (bIsDeveloper(iSurvivor, 4) || bIsDeveloper(iSurvivor, 6));
		if (bDeveloper || ((g_esPlayer[iSurvivor].g_iRewardTypes & MT_REWARD_AMMO) && g_esPlayer[iSurvivor].g_iAmmoBoost == 1))
		{
			hReturn.Value = iClip;

			return MRES_Override;
		}
	}

	return MRES_Ignored;
}

MRESReturn mreHitByVomitJarPre(int pThis, DHookParam hParams)
{
	int iSurvivor = hParams.IsNull(1) ? 0 : hParams.Get(1);
	if (bIsTank(pThis) && g_esCache[pThis].g_iVomitImmunity == 1 && bIsSurvivor(iSurvivor, MT_CHECK_INDEX|MT_CHECK_INGAME) && !(g_esPlayer[iSurvivor].g_iRewardTypes & MT_REWARD_DAMAGEBOOST))
	{
		return MRES_Supercede;
	}

	Action aResult = Plugin_Continue;
	Call_StartForward(g_esGeneral.g_gfPlayerHitByVomitJarForward);
	Call_PushCell(pThis);
	Call_PushCell(iSurvivor);
	Call_Finish(aResult);

	return (aResult == Plugin_Handled) ? MRES_Supercede : MRES_Ignored;
}

MRESReturn mreIncapacitatedAsTankPre(int pThis, DHookParam hParams)
{
	if (bIsTank(pThis) && g_esCache[pThis].g_iSkipIncap == 1 && g_esGeneral.g_cvMTTankIncapHealth != null)
	{
		g_esGeneral.g_iDefaultTankIncapHealth = g_esGeneral.g_cvMTTankIncapHealth.IntValue;
		g_esGeneral.g_cvMTTankIncapHealth.IntValue = 0;

		return MRES_Override;
	}

	return MRES_Ignored;
}

MRESReturn mreIncapacitatedAsTankPost(int pThis, DHookParam hParams)
{
	if (g_esGeneral.g_iDefaultTankIncapHealth != -1)
	{
		g_esGeneral.g_cvMTTankIncapHealth.IntValue = g_esGeneral.g_iDefaultTankIncapHealth;
		g_esGeneral.g_iDefaultTankIncapHealth = -1;
	}

	return MRES_Ignored;
}

MRESReturn mreInitialContainedActionPre(Address pThis, DHookParam hParams)
{
	int iTank = hParams.Get(1);
	if (bIsTank(iTank) && bIsCoopMode() && g_esCache[iTank].g_iAutoAggravate == 1)
	{
		static int iIndex = -1;
		if (iIndex == -1)
		{
			iIndex = iGetPatchIndex("MTPatch_TankFinaleBehavior");
		}

		if (iIndex != -1)
		{
			vInstallPatch(iIndex);
		}
	}

	return MRES_Ignored;
}

MRESReturn mreInitialContainedActionPost(Address pThis, DHookParam hParams)
{
	static int iIndex = -1;
	if (iIndex == -1)
	{
		iIndex = iGetPatchIndex("MTPatch_TankFinaleBehavior");
	}

	if (iIndex != -1)
	{
		vRemovePatch(iIndex);
	}

	return MRES_Ignored;
}

MRESReturn mreITExpiredPost(int pThis)
{
	if (bIsValidClient(pThis, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE) && g_esPlayer[pThis].g_bVomited)
	{
		g_esPlayer[pThis].g_bVomited = false;

		vRestorePlayerGlow(pThis);
	}

	return MRES_Ignored;
}

MRESReturn mreLadderDismountPre(int pThis)
{
	if (bIsSurvivor(pThis) && (bIsDeveloper(pThis, 6) || ((g_esPlayer[pThis].g_iRewardTypes & MT_REWARD_ATTACKBOOST) && g_esPlayer[pThis].g_iLadderActions == 1)))
	{
		static int iIndex = -1;
		if (iIndex == -1)
		{
			iIndex = iGetPatchIndex("MTPatch_LadderDismount1");
		}

		if (iIndex != -1)
		{
			vInstallPatch(iIndex);
		}
	}

	return MRES_Ignored;
}

MRESReturn mreLadderDismountPost(int pThis)
{
	static int iIndex = -1;
	if (iIndex == -1)
	{
		iIndex = iGetPatchIndex("MTPatch_LadderDismount1");
	}

	if (iIndex != -1)
	{
		vRemovePatch(iIndex);
	}

	return MRES_Ignored;
}

MRESReturn mreLadderMountPre(int pThis)
{
	if (bIsSurvivor(pThis) && (bIsDeveloper(pThis, 6) || ((g_esPlayer[pThis].g_iRewardTypes & MT_REWARD_ATTACKBOOST) && g_esPlayer[pThis].g_iLadderActions == 1)))
	{
		static int iIndex = -1;
		if (iIndex == -1)
		{
			iIndex = iGetPatchIndex("MTPatch_LadderMount1");
		}

		if (iIndex != -1)
		{
			vInstallPatch(iIndex);
		}
	}

	return MRES_Ignored;
}

MRESReturn mreLadderMountPost(int pThis)
{
	static int iIndex = -1;
	if (iIndex == -1)
	{
		iIndex = iGetPatchIndex("MTPatch_LadderMount1");
	}

	if (iIndex != -1)
	{
		vRemovePatch(iIndex);
	}

	return MRES_Ignored;
}

MRESReturn mreLaunchDirectionPre(int pThis)
{
	if (bIsValidEntity(pThis))
	{
		g_esGeneral.g_iLauncher = EntIndexToEntRef(pThis);
	}

	return MRES_Ignored;
}

MRESReturn mreLeaveStasisPost(int pThis)
{
	if (bIsTank(pThis))
	{
		g_esPlayer[pThis].g_bStasis = false;
	}

	return MRES_Ignored;
}

MRESReturn mreMaxCarryPre(Address pThis, DHookReturn hReturn, DHookParam hParams)
{
	int iSurvivor = hParams.IsNull(2) ? 0 : hParams.Get(2), iAmmo = iGetMaxAmmo(iSurvivor, hParams.Get(1), 0, true);
	if (bIsSurvivor(iSurvivor) && iAmmo > 0)
	{
		bool bDeveloper = (bIsDeveloper(iSurvivor, 4) || bIsDeveloper(iSurvivor, 6));
		if (bDeveloper || ((g_esPlayer[iSurvivor].g_iRewardTypes & MT_REWARD_AMMO) && g_esPlayer[iSurvivor].g_iAmmoBoost == 1))
		{
			hReturn.Value = iAmmo;

			return MRES_Override;
		}
	}

	return MRES_Ignored;
}

MRESReturn mrePipeBombProjectileCreatePre(DHookReturn hReturn, DHookParam hParams)
{
	int iSurvivor = hParams.IsNull(5) ? 0 : hParams.Get(5);
	if (bIsSurvivor(iSurvivor) && g_esGeneral.g_cvMTPipeBombDuration != null)
	{
		bool bDeveloper = bIsDeveloper(iSurvivor, 4);
		if (bDeveloper || (g_esPlayer[iSurvivor].g_iRewardTypes & MT_REWARD_DAMAGEBOOST))
		{
			float flDuration = (bDeveloper && g_esDeveloper[iSurvivor].g_flDevPipeBombDuration > g_esPlayer[iSurvivor].g_flPipeBombDuration) ? g_esDeveloper[iSurvivor].g_flDevPipeBombDuration : g_esPlayer[iSurvivor].g_flPipeBombDuration;
			if (flDuration > 0.0)
			{
				g_esGeneral.g_flDefaultPipeBombDuration = g_esGeneral.g_cvMTPipeBombDuration.FloatValue;
				g_esGeneral.g_cvMTPipeBombDuration.FloatValue = flDuration;
			}
		}
	}

	return MRES_Ignored;
}

MRESReturn mrePipeBombProjectileCreatePost(DHookReturn hReturn, DHookParam hParams)
{
	if (g_esGeneral.g_flDefaultPipeBombDuration != -1.0)
	{
		g_esGeneral.g_cvMTPipeBombDuration.FloatValue = g_esGeneral.g_flDefaultPipeBombDuration;
		g_esGeneral.g_flDefaultPipeBombDuration = -1.0;
	}

	return MRES_Ignored;
}

MRESReturn mrePreThinkPre(int pThis)
{
	if (bIsSurvivor(pThis) && (bIsDeveloper(pThis, 6) || ((g_esPlayer[pThis].g_iRewardTypes & MT_REWARD_ATTACKBOOST) && g_esPlayer[pThis].g_iLadderActions == 1)))
	{
		static int iIndex = -1;
		if (iIndex == -1)
		{
			iIndex = iGetPatchIndex("MTPatch_LadderDismount2");
		}

		if (iIndex != -1)
		{
			vInstallPatch(iIndex);
		}
	}

	return MRES_Ignored;
}

MRESReturn mrePreThinkPost(int pThis)
{
	static int iIndex = -1;
	if (iIndex == -1)
	{
		iIndex = iGetPatchIndex("MTPatch_LadderDismount2");
	}

	if (iIndex != -1)
	{
		vRemovePatch(iIndex);
	}

	return MRES_Ignored;
}

MRESReturn mreReplaceTankPost(DHookParam hParams)
{
	int iOldTank = hParams.IsNull(1) ? 0 : hParams.Get(1), iNewTank = hParams.IsNull(2) ? 0 : hParams.Get(2),
		iType = (g_esPlayer[iNewTank].g_iPersonalType > 0) ? g_esPlayer[iNewTank].g_iPersonalType : g_esPlayer[iOldTank].g_iTankType;

	g_esPlayer[iNewTank].g_bReplaceSelf = true;

	vSetTankColor(iNewTank, iType);
	vCopyTankStats(iOldTank, iNewTank);
	vTankSpawn(iNewTank, -1);
	vResetTank(iOldTank, 0);
	vResetTank2(iOldTank);
	vCacheSettings(iOldTank);

	return MRES_Ignored;
}

MRESReturn mreRevivedPre(int pThis)
{
	if (bIsSurvivor(pThis) && g_esGeneral.g_cvMTSurvivorReviveHealth != null)
	{
		bool bDeveloper = bIsDeveloper(pThis, 6);
		if (bDeveloper || (g_esPlayer[pThis].g_iRewardTypes & MT_REWARD_HEALTH))
		{
			int iHealth = (bDeveloper && g_esDeveloper[pThis].g_iDevReviveHealth > g_esPlayer[pThis].g_iReviveHealth) ? g_esDeveloper[pThis].g_iDevReviveHealth : g_esPlayer[pThis].g_iReviveHealth;
			if (iHealth > 0)
			{
				g_esGeneral.g_iDefaultSurvivorReviveHealth = g_esGeneral.g_cvMTSurvivorReviveHealth.IntValue;
				g_esGeneral.g_cvMTSurvivorReviveHealth.IntValue = iHealth;
			}
		}
	}

	return MRES_Ignored;
}

MRESReturn mreRevivedPost(int pThis)
{
	if (g_esGeneral.g_iDefaultSurvivorReviveHealth != -1)
	{
		g_esGeneral.g_cvMTSurvivorReviveHealth.IntValue = g_esGeneral.g_iDefaultSurvivorReviveHealth;
		g_esGeneral.g_iDefaultSurvivorReviveHealth = -1;
	}

	return MRES_Ignored;
}

MRESReturn mreSecondaryAttackPre(int pThis)
{
	int iSurvivor = !bIsValidEntity(pThis) ? 0 : GetEntPropEnt(pThis, Prop_Send, "m_hOwner");
	if (bIsSurvivor(iSurvivor) && g_esGeneral.g_cvMTGunSwingInterval != null)
	{
		bool bDeveloper = bIsDeveloper(iSurvivor, 6);
		if (bDeveloper || (g_esPlayer[iSurvivor].g_iRewardTypes & MT_REWARD_ATTACKBOOST))
		{
			float flMultiplier = (bDeveloper && g_esDeveloper[iSurvivor].g_flDevShoveRate > g_esPlayer[iSurvivor].g_flShoveRate) ? g_esDeveloper[iSurvivor].g_flDevShoveRate : g_esPlayer[iSurvivor].g_flShoveRate;
			if (flMultiplier > 0.0)
			{
				g_esGeneral.g_flDefaultGunSwingInterval = g_esGeneral.g_cvMTGunSwingInterval.FloatValue;
				g_esGeneral.g_cvMTGunSwingInterval.FloatValue *= flMultiplier;
			}
		}
	}

	return MRES_Ignored;
}

MRESReturn mreSecondaryAttackPost(int pThis)
{
	if (g_esGeneral.g_flDefaultGunSwingInterval != -1.0)
	{
		g_esGeneral.g_cvMTGunSwingInterval.FloatValue = g_esGeneral.g_flDefaultGunSwingInterval;
		g_esGeneral.g_flDefaultGunSwingInterval = -1.0;
	}

	return MRES_Ignored;
}

MRESReturn mreSelectWeightedSequencePre(int pThis, DHookReturn hReturn, DHookParam hParams)
{
	if (bIsTank(pThis) && g_esCache[pThis].g_iSkipTaunt == 1 && MT_ACT_TERROR_HULK_VICTORY <= hParams.Get(1) <= MT_ACT_TERROR_RAGE_AT_KNOCKDOWN)
	{
		hReturn.Value = 0;

		SetEntPropFloat(pThis, Prop_Send, "m_flCycle", 1000.0);

		return MRES_ChangedOverride;
	}

	return MRES_Ignored;
}

MRESReturn mreShovedByPounceLandingPre(int pThis, DHookParam hParams)
{
	if (bIsSurvivor(pThis) && (bIsDeveloper(pThis, 8) || (g_esPlayer[pThis].g_iRewardTypes & MT_REWARD_GODMODE)))
	{
		return MRES_Supercede;
	}

	return MRES_Ignored;
}

MRESReturn mreShovedBySurvivorPre(int pThis, DHookParam hParams)
{
	int iSurvivor = hParams.IsNull(1) ? 0 : hParams.Get(1);
	float flDirection[3];
	hParams.GetVector(2, flDirection);

	Action aResult = Plugin_Continue;
	Call_StartForward(g_esGeneral.g_gfPlayerShovedBySurvivorForward);
	Call_PushCell(pThis);
	Call_PushCell(iSurvivor);
	Call_PushArray(flDirection, sizeof flDirection);
	Call_Finish(aResult);

	return (aResult == Plugin_Handled) ? MRES_Supercede : MRES_Ignored;
}

MRESReturn mreSetMainActivityPre(int pThis, DHookParam hParams)
{
	if (bIsSurvivor(pThis) && (bIsDeveloper(pThis, 6) || (g_esPlayer[pThis].g_iRewardTypes & MT_REWARD_ATTACKBOOST)))
	{
		int iActivity = hParams.Get(1);
		if (iActivity == MT_ACT_TERROR_HIT_BY_TANKPUNCH || iActivity == MT_ACT_TERROR_IDLE_FALL_FROM_TANKPUNCH || iActivity == MT_ACT_TERROR_POUNCED_TO_STAND || iActivity == MT_ACT_TERROR_TANKROCK_TO_STAND)
		{
			hParams.Set(1, MT_ACT_TERROR_TANKPUNCH_LAND);

			return MRES_ChangedHandled;
		}
	}

	return MRES_Ignored;
}

MRESReturn mreSpawnTankPre(DHookReturn hReturn, DHookParam hParams)
{
	if (g_esGeneral.g_iLimitExtras == 0 || g_esGeneral.g_bForceSpawned)
	{
		return MRES_Ignored;
	}

	bool bBlock = false;
	int iCount = iGetTankCount(true), iCount2 = iGetTankCount(false);

	switch (g_esGeneral.g_bFinalMap)
	{
		case true:
		{
			switch (g_esGeneral.g_iFinaleAmount)
			{
				case 0: bBlock = (0 < g_esGeneral.g_iFinaleWave[g_esGeneral.g_iTankWave] <= iCount) || (0 < g_esGeneral.g_iFinaleWave[g_esGeneral.g_iTankWave] <= iCount2);
				default: bBlock = (0 < g_esGeneral.g_iFinaleAmount <= iCount) || (0 < g_esGeneral.g_iFinaleAmount <= iCount2);
			}
		}
		case false: bBlock = (0 < g_esGeneral.g_iRegularAmount <= iCount) || (0 < g_esGeneral.g_iRegularAmount <= iCount2);
	}

	if (bBlock)
	{
		hReturn.Value = 0;

		return MRES_Supercede;
	}

	return MRES_Ignored;
}

MRESReturn mreStaggeredPre(int pThis, DHookParam hParams)
{
	if (bIsSurvivor(pThis) && (bIsDeveloper(pThis, 8) || (g_esPlayer[pThis].g_iRewardTypes & MT_REWARD_GODMODE)))
	{
		return MRES_Supercede;
	}

	return MRES_Ignored;
}

MRESReturn mreStartActionPre(int pThis, DHookReturn hReturn, DHookParam hParams)
{
	int iSurvivor = !bIsValidEntity(pThis) ? 0 : GetEntPropEnt(pThis, Prop_Send, "m_hOwner");
	if (bIsSurvivor(iSurvivor) && g_esGeneral.g_hSDKGetUseAction != null)
	{
		bool bDeveloper = bIsDeveloper(iSurvivor, 6);
		if (bDeveloper || (g_esPlayer[iSurvivor].g_iRewardTypes & MT_REWARD_ATTACKBOOST))
		{
			float flDuration = (bDeveloper && g_esDeveloper[iSurvivor].g_flDevActionDuration > g_esPlayer[iSurvivor].g_flActionDuration) ? g_esDeveloper[iSurvivor].g_flDevActionDuration : g_esPlayer[iSurvivor].g_flActionDuration;
			if (flDuration > 0.0)
			{
				vSetDurationCvars(pThis, false, flDuration);
			}
		}
	}

	return MRES_Ignored;
}

MRESReturn mreStartActionPost(int pThis, DHookReturn hReturn, DHookParam hParams)
{
	if (g_esGeneral.g_hSDKGetUseAction != null)
	{
		vSetDurationCvars(pThis, true);
	}

	return MRES_Ignored;
}

MRESReturn mreStartHealingLinuxPre(DHookParam hParams)
{
	int pThis = hParams.Get(1), iSurvivor = !bIsValidEntity(pThis) ? 0 : GetEntPropEnt(pThis, Prop_Send, "m_hOwner");
	if (bIsSurvivor(iSurvivor) && g_esGeneral.g_cvMTFirstAidKitUseDuration != null)
	{
		bool bDeveloper = bIsDeveloper(iSurvivor, 6);
		if (bDeveloper || (g_esPlayer[iSurvivor].g_iRewardTypes & MT_REWARD_ATTACKBOOST))
		{
			float flDuration = (bDeveloper && g_esDeveloper[iSurvivor].g_flDevActionDuration > g_esPlayer[iSurvivor].g_flActionDuration) ? g_esDeveloper[iSurvivor].g_flDevActionDuration : g_esPlayer[iSurvivor].g_flActionDuration;
			if (flDuration > 0.0)
			{
				g_esGeneral.g_flDefaultFirstAidKitUseDuration = g_esGeneral.g_cvMTFirstAidKitUseDuration.FloatValue;
				g_esGeneral.g_cvMTFirstAidKitUseDuration.FloatValue = flDuration;
			}
		}
	}

	return MRES_Ignored;
}

MRESReturn mreStartHealingLinuxPost(DHookParam hParams)
{
	if (g_esGeneral.g_flDefaultFirstAidKitUseDuration != -1.0)
	{
		g_esGeneral.g_cvMTFirstAidKitUseDuration.FloatValue = g_esGeneral.g_flDefaultFirstAidKitUseDuration;
		g_esGeneral.g_flDefaultFirstAidKitUseDuration = -1.0;
	}

	return MRES_Ignored;
}

MRESReturn mreStartHealingWindowsPre(int pThis, DHookParam hParams)
{
	int iSurvivor = !bIsValidEntity(pThis) ? 0 : GetEntPropEnt(pThis, Prop_Send, "m_hOwner");
	if (bIsSurvivor(iSurvivor) && g_esGeneral.g_cvMTFirstAidKitUseDuration != null)
	{
		bool bDeveloper = bIsDeveloper(iSurvivor, 6);
		if (bDeveloper || (g_esPlayer[iSurvivor].g_iRewardTypes & MT_REWARD_ATTACKBOOST))
		{
			float flDuration = (bDeveloper && g_esDeveloper[iSurvivor].g_flDevActionDuration > g_esPlayer[iSurvivor].g_flActionDuration) ? g_esDeveloper[iSurvivor].g_flDevActionDuration : g_esPlayer[iSurvivor].g_flActionDuration;
			if (flDuration > 0.0)
			{
				g_esGeneral.g_flDefaultFirstAidKitUseDuration = g_esGeneral.g_cvMTFirstAidKitUseDuration.FloatValue;
				g_esGeneral.g_cvMTFirstAidKitUseDuration.FloatValue = flDuration;
			}
		}
	}

	return MRES_Ignored;
}

MRESReturn mreStartHealingWindowsPost(int pThis, DHookParam hParams)
{
	if (g_esGeneral.g_flDefaultFirstAidKitUseDuration != -1.0)
	{
		g_esGeneral.g_cvMTFirstAidKitUseDuration.FloatValue = g_esGeneral.g_flDefaultFirstAidKitUseDuration;
		g_esGeneral.g_flDefaultFirstAidKitUseDuration = -1.0;
	}

	return MRES_Ignored;
}

MRESReturn mreStartRevivingPre(int pThis, DHookParam hParams)
{
	if (g_esGeneral.g_cvMTSurvivorReviveDuration != null)
	{
		int iTarget = hParams.IsNull(1) ? 0 : hParams.Get(1);
		if (bIsSurvivor(pThis) && (bIsDeveloper(pThis, 6) || (g_esPlayer[pThis].g_iRewardTypes & MT_REWARD_ATTACKBOOST)))
		{
			vSetReviveDurationCvar(pThis);
		}
		else if (bIsSurvivor(iTarget) && (bIsDeveloper(iTarget, 6) || (g_esPlayer[iTarget].g_iRewardTypes & MT_REWARD_ATTACKBOOST)))
		{
			vSetReviveDurationCvar(iTarget);
		}

		g_esPlayer[iTarget].g_iReviver = GetClientUserId(pThis);
	}

	return MRES_Ignored;
}

MRESReturn mreStartRevivingPost(int pThis, DHookParam hParams)
{
	if (g_esGeneral.g_flDefaultSurvivorReviveDuration != -1.0)
	{
		g_esGeneral.g_cvMTSurvivorReviveDuration.FloatValue = g_esGeneral.g_flDefaultSurvivorReviveDuration;
		g_esGeneral.g_flDefaultSurvivorReviveDuration = -1.0;
	}

	return MRES_Ignored;
}

MRESReturn mreTankClawDoSwingPre(int pThis)
{
	int iTank = !bIsValidEntity(pThis) ? 0 : GetEntPropEnt(pThis, Prop_Send, "m_hOwner");
	if (bIsTank(iTank) && g_esCache[iTank].g_iSweepFist == 1)
	{
		char sName[32];
		static int iIndex[2] = {-1, -1};
		for (int iPos = 0; iPos < (sizeof iIndex); iPos++)
		{
			if (iIndex[iPos] == -1)
			{
				FormatEx(sName, sizeof sName, "MTPatch_TankSweepFist%i", (iPos + 1));
				iIndex[iPos] = iGetPatchIndex(sName);
			}

			if (iIndex[iPos] != -1)
			{
				vInstallPatch(iIndex[iPos]);
			}
		}
	}

	return MRES_Ignored;
}

MRESReturn mreTankClawDoSwingPost(int pThis)
{
	char sName[32];
	static int iIndex[2] = {-1, -1};
	for (int iPos = 0; iPos < (sizeof iIndex); iPos++)
	{
		if (iIndex[iPos] == -1)
		{
			FormatEx(sName, sizeof sName, "MTPatch_TankSweepFist%i", (iPos + 1));
			iIndex[iPos] = iGetPatchIndex(sName);
		}

		if (iIndex[iPos] != -1)
		{
			vRemovePatch(iIndex[iPos]);
		}
	}

	return MRES_Ignored;
}

MRESReturn mreTankClawGroundPoundPre(int pThis)
{
	int iTank = !bIsValidEntity(pThis) ? 0 : GetEntPropEnt(pThis, Prop_Send, "m_hOwner");
	if (bIsTank(iTank) && g_esCache[iTank].g_iGroundPound == 1)
	{
		static int iIndex = -1;
		if (iIndex == -1)
		{
			iIndex = iGetPatchIndex("MTPatch_TankGroundPound");
		}

		if (iIndex != -1)
		{
			vInstallPatch(iIndex);
		}
	}

	return MRES_Ignored;
}

MRESReturn mreTankClawGroundPoundPost(int pThis)
{
	static int iIndex = -1;
	if (iIndex == -1)
	{
		iIndex = iGetPatchIndex("MTPatch_TankGroundPound");
	}

	if (iIndex != -1)
	{
		vRemovePatch(iIndex);
	}

	return MRES_Ignored;
}

MRESReturn mreTankClawPlayerHitPre(int pThis, DHookParam hParams)
{
	int iSurvivor = hParams.IsNull(1) ? 0 : hParams.Get(1);
	if (bIsSurvivor(iSurvivor) && bIsDeveloper(iSurvivor, 8))
	{
		return MRES_Supercede;
	}

	return MRES_Ignored;
}

MRESReturn mreTankClawPlayerHitPost(int pThis, DHookParam hParams)
{
	int iTank = !bIsValidEntity(pThis) ? 0 : GetEntPropEnt(pThis, Prop_Send, "m_hOwner"), iSurvivor = hParams.IsNull(1) ? 0 : hParams.Get(1);
	if (bIsTank(iTank) && bIsSurvivor(iSurvivor))
	{
		bool bDeveloper = bIsDeveloper(iSurvivor, 4);
		if (g_esCache[iTank].g_flPunchForce >= 0.0 || bDeveloper || (g_esPlayer[iSurvivor].g_iRewardTypes & MT_REWARD_GODMODE))
		{
			float flVelocity[3], flForce = flGetPunchForce(iSurvivor, g_esCache[iTank].g_flPunchForce);
			if (flForce >= 0.0)
			{
				GetEntPropVector(iSurvivor, Prop_Data, "m_vecVelocity", flVelocity);
				ScaleVector(flVelocity, flForce);
				TeleportEntity(iSurvivor, .velocity = flVelocity);
			}
		}
	}

	return MRES_Ignored;
}

MRESReturn mreTankClawPrimaryAttackPre(int pThis)
{
	int iTank = !bIsValidEntity(pThis) ? 0 : GetEntPropEnt(pThis, Prop_Send, "m_hOwner");
	if (bIsTank(iTank) && g_esCache[iTank].g_flAttackInterval > 0.0)
	{
		float flCurrentTime = GetGameTime();
		if ((g_esPlayer[iTank].g_flLastAttackTime + g_esCache[iTank].g_flAttackInterval) > flCurrentTime)
		{
			return MRES_Supercede;
		}

		g_esPlayer[iTank].g_flLastAttackTime = flCurrentTime;
	}

	return MRES_Ignored;
}

MRESReturn mreTankRockCreatePost(DHookReturn hReturn, DHookParam hParams)
{
	if (hParams.IsNull(4))
	{
		vSetRockColor(hReturn.Value);
	}

	return MRES_Ignored;
}

MRESReturn mreTankRockDetonatePre(int pThis)
{
	if (bIsValidEntity(pThis))
	{
		int iThrower = GetEntPropEnt(pThis, Prop_Data, "m_hThrower");
		if (bIsTank(iThrower))
		{
			Call_StartForward(g_esGeneral.g_gfRockBreakForward);
			Call_PushCell(iThrower);
			Call_PushCell(pThis);
			Call_Finish();

			vCombineAbilitiesForward(iThrower, MT_COMBO_ROCKBREAK, .weapon = pThis);
		}
	}

	return MRES_Ignored;
}

MRESReturn mreTankRockReleaseLinuxPre(DHookParam hParams)
{
	int pThis = hParams.Get(1), iThrower = !bIsValidEntity(pThis) ? 0 : GetEntPropEnt(pThis, Prop_Data, "m_hThrower");
	if (bIsTank(iThrower) && g_esCache[iThrower].g_iRockSound == 0)
	{
		static int iIndex = -1;
		if (iIndex == -1)
		{
			iIndex = iGetPatchIndex("MTPatch_TankRockRelease");
		}

		if (iIndex != -1)
		{
			vInstallPatch(iIndex);
		}
	}

	return MRES_Ignored;
}

MRESReturn mreTankRockReleaseLinuxPost(DHookParam hParams)
{
	static int iIndex = -1;
	if (iIndex == -1)
	{
		iIndex = iGetPatchIndex("MTPatch_TankRockRelease");
	}

	if (iIndex != -1)
	{
		vRemovePatch(iIndex);
	}

	return MRES_Ignored;
}

MRESReturn mreTankRockReleaseWindowsPre(int pThis, DHookParam hParams)
{
	int iThrower = !bIsValidEntity(pThis) ? 0 : GetEntPropEnt(pThis, Prop_Data, "m_hThrower");
	if (bIsTank(iThrower) && g_esCache[iThrower].g_iRockSound == 0)
	{
		static int iIndex = -1;
		if (iIndex == -1)
		{
			iIndex = iGetPatchIndex("MTPatch_TankRockRelease");
		}

		if (iIndex != -1)
		{
			vInstallPatch(iIndex);
		}
	}

	return MRES_Ignored;
}

MRESReturn mreTankRockReleaseWindowsPost(int pThis, DHookParam hParams)
{
	static int iIndex = -1;
	if (iIndex == -1)
	{
		iIndex = iGetPatchIndex("MTPatch_TankRockRelease");
	}

	if (iIndex != -1)
	{
		vRemovePatch(iIndex);
	}

	return MRES_Ignored;
}

MRESReturn mreTestMeleeSwingCollisionPre(int pThis, DHookParam hParams)
{
	int iSurvivor = !bIsValidEntity(pThis) ? 0 : GetEntPropEnt(pThis, Prop_Send, "m_hOwner");
	if (bIsSurvivor(iSurvivor) && g_esGeneral.g_cvMTMeleeRange != null)
	{
		bool bDeveloper = bIsDeveloper(iSurvivor, 6);
		if (bDeveloper || (g_esPlayer[iSurvivor].g_iRewardTypes & MT_REWARD_DAMAGEBOOST))
		{
			int iRange = (bDeveloper && g_esDeveloper[iSurvivor].g_iDevMeleeRange > g_esPlayer[iSurvivor].g_iMeleeRange) ? g_esDeveloper[iSurvivor].g_iDevMeleeRange : g_esPlayer[iSurvivor].g_iMeleeRange;
			if (iRange > 0)
			{
				g_esGeneral.g_iDefaultMeleeRange = g_esGeneral.g_cvMTMeleeRange.IntValue;
				g_esGeneral.g_cvMTMeleeRange.IntValue = iRange;
			}
		}
	}

	return MRES_Ignored;
}

MRESReturn mreTestMeleeSwingCollisionPost(int pThis, DHookParam hParams)
{
	if (g_esGeneral.g_iDefaultMeleeRange != -1)
	{
		g_esGeneral.g_cvMTMeleeRange.IntValue = g_esGeneral.g_iDefaultMeleeRange;
		g_esGeneral.g_iDefaultMeleeRange = -1;
	}

	return MRES_Ignored;
}

MRESReturn mreThrowActivateAbilityPre(int pThis)
{
	int iTank = !bIsValidEntity(pThis) ? 0 : GetEntPropEnt(pThis, Prop_Send, "m_hOwnerEntity");
	if (bIsTank(iTank) && g_esCache[iTank].g_flThrowInterval > 0.0)
	{
		float flCurrentTime = GetGameTime();
		if ((g_esPlayer[iTank].g_flLastThrowTime + g_esCache[iTank].g_flThrowInterval) > flCurrentTime)
		{
			return MRES_Supercede;
		}

		g_esPlayer[iTank].g_flLastThrowTime = flCurrentTime;
	}

	return MRES_Ignored;
}

MRESReturn mreUsePre(int pThis, DHookParam hParams)
{
	int iSurvivor = hParams.Get(1);
	if (bIsSurvivor(iSurvivor) && (bIsDeveloper(iSurvivor, 6) || (g_esPlayer[iSurvivor].g_iRewardTypes & MT_REWARD_ATTACKBOOST)))
	{
		char sName[32];
		static int iIndex[3] = {-1, -1, -1};
		for (int iPos = 0; iPos < (sizeof iIndex); iPos++)
		{
			if (iIndex[iPos] == -1)
			{
				FormatEx(sName, sizeof sName, "MTPatch_EquipSecondWeapon%i", (iPos + 1));
				iIndex[iPos] = iGetPatchIndex(sName);
			}

			if (iIndex[iPos] != -1)
			{
				vInstallPatch(iIndex[iPos]);
			}
		}
	}

	return MRES_Ignored;
}

MRESReturn mreUsePost(int pThis, DHookParam hParams)
{
	char sName[32];
	static int iIndex[3] = {-1, -1, -1};
	for (int iPos = 0; iPos < (sizeof iIndex); iPos++)
	{
		if (iIndex[iPos] == -1)
		{
			FormatEx(sName, sizeof sName, "MTPatch_EquipSecondWeapon%i", (iPos + 1));
			iIndex[iPos] = iGetPatchIndex(sName);
		}

		if (iIndex[iPos] != -1)
		{
			vRemovePatch(iIndex[iPos]);
		}
	}

	return MRES_Ignored;
}

MRESReturn mreVomitedUponPre(int pThis, DHookParam hParams)
{
	if (bIsSurvivor(pThis) && (bIsDeveloper(pThis, 8) || bIsDeveloper(pThis, 10) || (g_esPlayer[pThis].g_iRewardTypes & MT_REWARD_GODMODE)))
	{
		return MRES_Supercede;
	}

	return MRES_Ignored;
}

MRESReturn mreVomitedUponPost(int pThis, DHookParam hParams)
{
	if (bIsValidClient(pThis, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE) && !g_esPlayer[pThis].g_bVomited)
	{
		if (bIsSurvivor(pThis) && (bIsDeveloper(pThis, 8) || bIsDeveloper(pThis, 10) || (g_esPlayer[pThis].g_iRewardTypes & MT_REWARD_GODMODE)))
		{
			return MRES_Ignored;
		}

		g_esPlayer[pThis].g_bVomited = true;

		if (bIsTank(pThis) || bIsSurvivor(pThis))
		{
			vRemovePlayerGlow(pThis);
		}
	}

	return MRES_Ignored;
}

/**
 * Patch functions
 **/

void vInstallPatch(int index, bool override = false)
{
	if (index >= g_esGeneral.g_iPatchCount)
	{
		LogError("%s Patch #%i out of range when installing patch. (Maximum: %i)", MT_TAG, index, (g_esGeneral.g_iPatchCount - 1));

		return;
	}

	if ((g_esPatch[index].g_iType == 2 && !override) || g_esPatch[index].g_bInstalled)
	{
		return;
	}

	for (int iPos = 0; iPos < g_esPatch[index].g_iLength; iPos++)
	{
		g_esPatch[index].g_iOriginalBytes[iPos] = LoadFromAddress((g_esPatch[index].g_adPatch + view_as<Address>(g_esPatch[index].g_iOffset + iPos)), NumberType_Int8);
		StoreToAddress((g_esPatch[index].g_adPatch + view_as<Address>(g_esPatch[index].g_iOffset + iPos)), g_esPatch[index].g_iPatchBytes[iPos], NumberType_Int8, g_esPatch[index].g_bUpdateMemAccess);
	}

	g_esPatch[index].g_bInstalled = true;
	g_esPatch[index].g_bUpdateMemAccess = false;

	if (g_esPatch[index].g_iType == 2 && g_esPatch[index].g_bLog)
	{
		vLogMessage(-1, _, "%s Enabled the \"%s\" patch.", MT_TAG, g_esPatch[index].g_sName);
	}
}

void vInstallPermanentPatches()
{
	for (int iPos = 0; iPos < g_esGeneral.g_iPatchCount; iPos++)
	{
		if (g_esPatch[iPos].g_sName[0] != '\0' && g_esPatch[iPos].g_iType == 2 && !g_esPatch[iPos].g_bInstalled)
		{
			vInstallPatch(iPos, true);
		}
	}
}

void vReadPatchSettings(const char[] key, const char[] value)
{
	int iIndex = g_esGeneral.g_iPatchCount;
	g_esPatch[iIndex].g_bLog = !!iGetKeyValueEx(key, "Log", "Log", "Log", "Log", g_esPatch[iIndex].g_bLog, value, 0, 1);
	g_esPatch[iIndex].g_iType = iGetKeyValueEx(key, "Type", "Type", "Type", "Type", g_esPatch[iIndex].g_iType, value, 0, 2);

	vGetKeyValueEx(key, "CvarCheck", "Cvar Check", "Cvar_Check", "cvars", g_esPatch[iIndex].g_sCvars, sizeof esPatch::g_sCvars, value);
	vGetKeyValueEx(key, "Signature", "Signature", "Signature", "Signature", g_esPatch[iIndex].g_sSignature, sizeof esPatch::g_sSignature, value);
	vGetKeyValueEx(key, "Offset", "Offset", "Offset", "Offset", g_esPatch[iIndex].g_sOffset, sizeof esPatch::g_sOffset, value);
	vGetKeyValueEx(key, "Verify", "Verify", "Verify", "Verify", g_esPatch[iIndex].g_sVerify, sizeof esPatch::g_sVerify, value);
	vGetKeyValueEx(key, "Bypass", "Bypass", "Bypass", "Bypass", g_esPatch[iIndex].g_sBypass, sizeof esPatch::g_sBypass, value);
	vGetKeyValueEx(key, "Patch", "Patch", "Patch", "Patch", g_esPatch[iIndex].g_sPatch, sizeof esPatch::g_sPatch, value);
}

void vRegisterPatch(const char[] name, bool reg)
{
	if (!reg)
	{
		g_esGeneral.g_bOverridePatch = true;

		return;
	}

	int iIndex = g_esGeneral.g_iPatchCount;
	if (g_esPatch[iIndex].g_iType == 0 || bIsConVarConflictFound(name, g_esPatch[iIndex].g_sCvars, "skipping", g_esPatch[iIndex].g_bLog))
	{
		vResetPatchInfo(iIndex);

		return;
	}

	if (g_esPatch[iIndex].g_bLog)
	{
		vLogMessage(-1, _, "%s Reading byte(s) for \"%s\": %s - %s - %s", MT_TAG, name, g_esPatch[iIndex].g_sBypass, g_esPatch[iIndex].g_sVerify, g_esPatch[iIndex].g_sPatch);
	}

	char sSet[MT_PATCH_MAXLEN][2];
	int iBypass[MT_PATCH_MAXLEN], iVerify[MT_PATCH_MAXLEN], iPatch[MT_PATCH_MAXLEN];

	ReplaceString(g_esPatch[iIndex].g_sBypass, sizeof esPatch::g_sBypass, "\\x", " ", false);
	TrimString(g_esPatch[iIndex].g_sBypass);
	int iBLength = ExplodeString(g_esPatch[iIndex].g_sBypass, " ", sSet, sizeof sSet, sizeof sSet[]);

	ReplaceString(g_esPatch[iIndex].g_sVerify, sizeof esPatch::g_sVerify, "\\x", " ", false);
	TrimString(g_esPatch[iIndex].g_sVerify);
	int iVLength = ExplodeString(g_esPatch[iIndex].g_sVerify, " ", sSet, sizeof sSet, sizeof sSet[]);

	ReplaceString(g_esPatch[iIndex].g_sPatch, sizeof esPatch::g_sPatch, "\\x", " ", false);
	TrimString(g_esPatch[iIndex].g_sPatch);
	int iPLength = ExplodeString(g_esPatch[iIndex].g_sPatch, " ", sSet, sizeof sSet, sizeof sSet[]);

	if (g_esPatch[iIndex].g_bLog)
	{
		vLogMessage(-1, _, "%s Storing byte(s) for \"%s\": %s - %s - %s", MT_TAG, name, g_esPatch[iIndex].g_sBypass, g_esPatch[iIndex].g_sVerify, g_esPatch[iIndex].g_sPatch);
	}

	if (g_esPatch[iIndex].g_sBypass[0] != '\0')
	{
		for (int iPos = 0; iPos < MT_PATCH_MAXLEN; iPos++)
		{
			switch (iPos < iBLength)
			{
				case true: iBypass[iPos] = (iGetDecimalFromHex(g_esPatch[iIndex].g_sBypass[iPos * 3]) << 4) + iGetDecimalFromHex(g_esPatch[iIndex].g_sBypass[(iPos * 3) + 1]);
				case false: iBypass[iPos] = 0;
			}
		}
	}

	for (int iPos = 0; iPos < MT_PATCH_MAXLEN; iPos++)
	{
		switch (iPos < iVLength)
		{
			case true: iVerify[iPos] = (iGetDecimalFromHex(g_esPatch[iIndex].g_sVerify[iPos * 3]) << 4) + iGetDecimalFromHex(g_esPatch[iIndex].g_sVerify[(iPos * 3) + 1]);
			case false: iVerify[iPos] = 0;
		}
	}

	for (int iPos = 0; iPos < MT_PATCH_MAXLEN; iPos++)
	{
		switch (iPos < iPLength)
		{
			case true: iPatch[iPos] = (iGetDecimalFromHex(g_esPatch[iIndex].g_sPatch[iPos * 3]) << 4) + iGetDecimalFromHex(g_esPatch[iIndex].g_sPatch[(iPos * 3) + 1]);
			case false: iPatch[iPos] = 0;
		}
	}

	Address adPatch = g_esGeneral.g_gdMutantTanks.GetMemSig(g_esPatch[iIndex].g_sSignature);
	if (adPatch == Address_Null)
	{
		vResetPatchInfo(iIndex);

		return;
	}

	int iOffset = 0;
	if (g_esPatch[iIndex].g_sOffset[0] != '\0')
	{
		iOffset = IsCharNumeric(g_esPatch[iIndex].g_sOffset[0]) ? StringToInt(g_esPatch[iIndex].g_sOffset) : iGetGameDataOffset(g_esPatch[iIndex].g_sOffset);
		if (iOffset == -1)
		{
			vResetPatchInfo(iIndex);

			return;
		}
	}

	bool bInvalid = false;
	char sBypass[192], sVerify[192], sActual[192];
	int iActualByte = 0;
	for (int iPos = 0; iPos < iVLength; iPos++)
	{
		if (iVerify[iPos] < 0 || iVerify[iPos] > 255 || iBypass[iPos] < 0 || iBypass[iPos] > 255)
		{
			LogError("%s Invalid byte to verify for %s (%i) [%i]", MT_TAG, name, iVerify[iPos], iBypass[iPos]);

			continue;
		}

		switch (sVerify[0] == '\0')
		{
			case true: FormatEx(sVerify, sizeof sVerify, "%02X", iVerify[iPos]);
			case false: Format(sVerify, sizeof sVerify, "%s %02X", sVerify, iVerify[iPos]);
		}

		switch (sBypass[0] == '\0')
		{
			case true: FormatEx(sBypass, sizeof sBypass, "%02X", iBypass[iPos]);
			case false: Format(sBypass, sizeof sBypass, "%s %02X", sBypass, iBypass[iPos]);
		}

		if (iVerify[iPos] != 0x2A)
		{
			iActualByte = LoadFromAddress((adPatch + view_as<Address>(iOffset + iPos)), NumberType_Int8);

			switch (sActual[0] == '\0')
			{
				case true: FormatEx(sActual, sizeof sActual, "%02X", iActualByte);
				case false: Format(sActual, sizeof sActual, "%s %02X", sActual, iActualByte);
			}

			if (iActualByte != iVerify[iPos])
			{
				switch (iBypass[iPos] == 0)
				{
					case true: bInvalid = true;
					case false: bInvalid = (iBypass[iPos] != 0x2A && iActualByte != iBypass[iPos]);
				}
			}
		}
		else
		{
			switch (sActual[0] == '\0')
			{
				case true: FormatEx(sActual, sizeof sActual, "2A");
				case false: Format(sActual, sizeof sActual, "%s 2A", sActual);
			}
		}
	}

	if (bInvalid)
	{
		LogError("%s Failed to locate patch: %s (%s) [Expected: %s | Bypassed: %s | Found: %s]", MT_TAG, name, g_esPatch[iIndex].g_sOffset, sVerify, sBypass, sActual);
		vResetPatchInfo(iIndex);

		return;
	}

	g_esPatch[iIndex].g_adPatch = adPatch;
	g_esPatch[iIndex].g_iOffset = iOffset;
	g_esPatch[iIndex].g_iLength = iPLength;
	g_esGeneral.g_iPatchCount++;

	for (int iPos = 0; iPos < iPLength; iPos++)
	{
		g_esPatch[iIndex].g_iPatchBytes[iPos] = iPatch[iPos];
		g_esPatch[iIndex].g_iOriginalBytes[iPos] = 0x00;
	}

	if (g_esPatch[iIndex].g_bLog)
	{
		vLogMessage(-1, _, "%s Patch byte(s) for \"%s\" - Expected byte(s): %s | Bypassed byte(s): %s | Found byte(s): %s", MT_TAG, name, sVerify, sBypass, sActual);
		vLogMessage(-1, _, "%s Registered the \"%s\" patch.", MT_TAG, name);
	}
}

void vRegisterPatches()
{
	char sFilePath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sFilePath, sizeof sFilePath, "%s%s.cfg", MT_CONFIG_FILEPATH, MT_CONFIG_FILE_PATCHES);
	if (!MT_FileExists(MT_CONFIG_FILEPATH, (MT_CONFIG_FILE_PATCHES ... ".cfg"), sFilePath, sFilePath, sizeof sFilePath))
	{
		LogError("%s Unable to load the \"%s\" config file.", MT_TAG, sFilePath);

		return;
	}

	SMCParser smcPatches = smcSetupParser(sFilePath, SMCParseStart_Patches, SMCNewSection_Patches, SMCKeyValues_Patches, SMCEndSection_Patches, SMCRawLine_Patches, SMCParseEnd_Patches);
	if (smcPatches != null)
	{
		delete smcPatches;
	}
}

void vRemovePatch(int index, bool override = false)
{
	if (index >= g_esGeneral.g_iPatchCount)
	{
		LogError("%s Patch #%i out of range when removing patch. (Maximum: %i)", MT_TAG, index, (g_esGeneral.g_iPatchCount - 1));

		return;
	}

	if ((g_esPatch[index].g_iType == 2 && !override) || !g_esPatch[index].g_bInstalled)
	{
		return;
	}

	for (int iPos = 0; iPos < g_esPatch[index].g_iLength; iPos++)
	{
		StoreToAddress((g_esPatch[index].g_adPatch + view_as<Address>(g_esPatch[index].g_iOffset + iPos)), g_esPatch[index].g_iOriginalBytes[iPos], NumberType_Int8, g_esPatch[index].g_bUpdateMemAccess);
	}

	g_esPatch[index].g_bInstalled = false;

	if (g_esPatch[index].g_iType == 2 && g_esPatch[index].g_bLog)
	{
		vLogMessage(-1, _, "%s Disabled the \"%s\" patch.", MT_TAG, g_esPatch[index].g_sName);
	}
}

void vRemovePermanentPatches()
{
	for (int iPos = 0; iPos < g_esGeneral.g_iPatchCount; iPos++)
	{
		if (g_esPatch[iPos].g_sName[0] != '\0' && g_esPatch[iPos].g_iType == 2 && g_esPatch[iPos].g_bInstalled)
		{
			vRemovePatch(iPos, true);
		}
	}
}

void vResetPatchInfo(int index)
{
	g_esGeneral.g_iPatchCount = index;
	g_esPatch[index].g_adPatch = Address_Null;
	g_esPatch[index].g_bInstalled = false;
	g_esPatch[index].g_bLog = false;
	g_esPatch[index].g_bUpdateMemAccess = true;
	g_esPatch[index].g_iLength = 0;
	g_esPatch[index].g_iOffset = 0;
	g_esPatch[index].g_iType = 0;
	g_esPatch[index].g_sBypass[0] = '\0';
	g_esPatch[index].g_sCvars[0] = '\0';
	g_esPatch[index].g_sOffset[0] = '\0';
	g_esPatch[index].g_sPatch[0] = '\0';
	g_esPatch[index].g_sName[0] = '\0';
	g_esPatch[index].g_sSignature[0] = '\0';
	g_esPatch[index].g_sVerify[0] = '\0';

	for (int iPos = 0; iPos < MT_PATCH_MAXLEN; iPos++)
	{
		g_esPatch[index].g_iOriginalBytes[iPos] = 0;
		g_esPatch[index].g_iPatchBytes[iPos] = 0;
	}
}

int iGetPatchIndex(const char[] name)
{
	for (int iPos = 0; iPos < g_esGeneral.g_iPatchCount; iPos++)
	{
		if (StrEqual(name, g_esPatch[iPos].g_sName))
		{
			return iPos;
		}
	}

	return -1;
}

/**
 * Dynamic signatures functions
 **/

void vReadSignatureSettings(const char[] key, const char[] value)
{
	int iIndex = g_esGeneral.g_iSignatureCount;
	g_esSignature[iIndex].g_bLog = !!iGetKeyValueEx(key, "Log", "Log", "Log", "Log", g_esSignature[iIndex].g_bLog, value, 0, 1);

	vGetKeyValueEx(key, "Library", "Library", "Library", "Library", g_esSignature[iIndex].g_sLibrary, sizeof esSignature::g_sLibrary, value);
	vGetKeyValueEx(key, "Signature", "Signature", "Signature", "Signature", g_esSignature[iIndex].g_sSignature, sizeof esSignature::g_sSignature, value);
	vGetKeyValueEx(key, "Offset", "Offset", "Offset", "Offset", g_esSignature[iIndex].g_sOffset, sizeof esSignature::g_sOffset, value);
	vGetKeyValueEx(key, "Start", "Start", "Start", "Start", g_esSignature[iIndex].g_sStart, sizeof esSignature::g_sStart, value);
	vGetKeyValueEx(key, "Before", "Before", "Before", "Before", g_esSignature[iIndex].g_sBefore, sizeof esSignature::g_sBefore, value);
	vGetKeyValueEx(key, "After", "After", "After", "After", g_esSignature[iIndex].g_sAfter, sizeof esSignature::g_sAfter, value);

	if (g_esSignature[iIndex].g_sLibrary[0] == '\0')
	{
		g_esSignature[iIndex].g_sLibrary = "server";
	}

	g_esSignature[iIndex].g_sdkLibrary = StrEqual(g_esSignature[iIndex].g_sLibrary, "server", false) ? SDKLibrary_Server : SDKLibrary_Engine;

	if (g_esSignature[iIndex].g_sStart[0] == '\0')
	{
		g_esSignature[iIndex].g_sStart = "\\x2A";
	}
}

void vRegisterSignature(const char[] name)
{
	int iIndex = g_esGeneral.g_iSignatureCount;
	g_esGeneral.g_iSignatureCount++;

	if (g_esSignature[iIndex].g_bLog)
	{
		vLogMessage(-1, _, "%s Registered the \"%s\" signature.", MT_TAG, name);
	}
}

void vRegisterSignatures()
{
	char sFilePath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sFilePath, sizeof sFilePath, "%s%s.cfg", MT_CONFIG_FILEPATH, MT_CONFIG_FILE_SIGNATURES);
	if (!MT_FileExists(MT_CONFIG_FILEPATH, (MT_CONFIG_FILE_SIGNATURES ... ".cfg"), sFilePath, sFilePath, sizeof sFilePath))
	{
		LogError("%s Unable to load the \"%s\" config file.", MT_TAG, sFilePath);

		return;
	}

	SMCParser smcSignatures = smcSetupParser(sFilePath, SMCParseStart_Signatures, SMCNewSection_Signatures, SMCKeyValues_Signatures, SMCEndSection_Signatures, SMCRawLine_Signatures, SMCParseEnd_Signatures);
	if (smcSignatures != null)
	{
		delete smcSignatures;
	}
}

void vSetupSignatureAddresses()
{
	char sFilePath[PLATFORM_MAX_PATH];
	int iCount = 0;
	BuildPath(Path_SM, sFilePath, sizeof sFilePath, "gamedata/%s.txt", MT_GAMEDATA_TEMP);
	File fTemp = OpenFile(sFilePath, "w", false);
	if (fTemp != null)
	{
		fTemp.WriteLine("\"Games\"");
		fTemp.WriteLine("{");
		fTemp.WriteLine("	\"%s\"", (g_bSecondGame ? "left4dead2" : "left4dead"));
		fTemp.WriteLine("	{");
		fTemp.WriteLine("		\"Signatures\"");
		fTemp.WriteLine("		{");

		for (int iPos = 0; iPos < g_esGeneral.g_iSignatureCount; iPos++)
		{
			if (g_esSignature[iPos].g_sName[0] == '\0' || g_esSignature[iPos].g_sSignature[0] == '\0')
			{
				LogError("%s Invalid information for signature #%i - %s (Address: %s)", MT_TAG, (iPos + 1), g_esSignature[iPos].g_sName, g_esSignature[iPos].g_sSignature);

				continue;
			}

			g_esSignature[iPos].g_adString = g_esGeneral.g_gdMutantTanks.GetMemSig(g_esSignature[iPos].g_sSignature);
			if (g_esSignature[iPos].g_adString == Address_Null)
			{
				fTemp.WriteLine("			\"%sRef\"", g_esSignature[iPos].g_sName[12]);
				fTemp.WriteLine("			{");
				fTemp.WriteLine("				\"library\"	\"%s\"", g_esSignature[iPos].g_sLibrary);
				fTemp.WriteLine("				\"windows\"	\"%s\"", g_esSignature[iPos].g_sSignature);
				fTemp.WriteLine("			}");

				iCount++;
			}
		}

		fTemp.WriteLine("		}");
		fTemp.WriteLine("	}");
		fTemp.WriteLine("}");
		fTemp.Flush();

		delete fTemp;
	}

	if (iCount > 0)
	{
		GameData gdTemp = new GameData(MT_GAMEDATA_TEMP);
		if (gdTemp == null)
		{
			LogError("%s Unable to load the \"%s\" gamedata file.", MT_TAG, MT_GAMEDATA_TEMP);

			return;
		}

		char sSignature[128];
		for (int iPos = 0; iPos < g_esGeneral.g_iSignatureCount; iPos++)
		{
			if (g_esSignature[iPos].g_adString != Address_Null)
			{
				continue;
			}

			FormatEx(sSignature, sizeof sSignature, "%sRef", g_esSignature[iPos].g_sName[12]);
			g_esSignature[iPos].g_adString = gdTemp.GetMemSig(sSignature);
		}

		delete gdTemp;
	}
}

void vSetupSignatures()
{
	char sFilePath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sFilePath, sizeof sFilePath, "gamedata/%s.txt", MT_GAMEDATA_TEMP);
	File fTemp = OpenFile(sFilePath, "w", false);
	if (fTemp != null)
	{
		fTemp.WriteLine("\"Games\"");
		fTemp.WriteLine("{");
		fTemp.WriteLine("	\"%s\"", (g_bSecondGame ? "left4dead2" : "left4dead"));
		fTemp.WriteLine("	{");
		fTemp.WriteLine("		\"Signatures\"");
		fTemp.WriteLine("		{");

		Address adPatch = Address_Null;
		char sHexAddress[64], sHexBytes[64], sSignature[1024], sTemp[1024];
		int iCount = 0, iOffset = 256, iStart = 0;
		for (int iPos = 0; iPos < g_esGeneral.g_iSignatureCount; iPos++)
		{
			adPatch = g_esSignature[iPos].g_adString;
			if (adPatch != Address_Null)
			{
				FormatEx(g_esSignature[iPos].g_sDynamicSig, sizeof esSignature::g_sDynamicSig, "%X", adPatch);
				vReverseAddress(g_esSignature[iPos].g_sDynamicSig, sHexAddress, sizeof sHexAddress);
				iStart = FormatEx(g_esSignature[iPos].g_sDynamicSig, sizeof esSignature::g_sDynamicSig, "%s", g_esSignature[iPos].g_sStart);

				if (g_esSignature[iPos].g_sOffset[0] != '\0')
				{
					iOffset = IsCharNumeric(g_esSignature[iPos].g_sOffset[0]) ? StringToInt(g_esSignature[iPos].g_sOffset) : iGetGameDataOffset(g_esSignature[iPos].g_sOffset);
				}

				for (int iIndex = ((iStart / 4) - 1); iIndex < iOffset; iIndex++)
				{
					StrCat(g_esSignature[iPos].g_sDynamicSig, sizeof esSignature::g_sDynamicSig, "\\x2A");

					if (g_esSignature[iPos].g_sOffset[0] == '\0')
					{
						FormatEx(sTemp, sizeof sTemp, "%s%s%s%s", g_esSignature[iPos].g_sDynamicSig, g_esSignature[iPos].g_sBefore, sHexAddress, g_esSignature[iPos].g_sAfter);
						vGetBinariesFromSignature(sTemp, sSignature, sizeof sSignature, iCount);
						if (PrepSDKCall_SetSignature(g_esSignature[iPos].g_sdkLibrary, sSignature, iCount))
						{
							break;
						}
					}
				}

				if (g_esSignature[iPos].g_sBefore[0] != '\0')
				{
					StrCat(g_esSignature[iPos].g_sDynamicSig, sizeof esSignature::g_sDynamicSig, g_esSignature[iPos].g_sBefore);
				}

				StrCat(g_esSignature[iPos].g_sDynamicSig, sizeof esSignature::g_sDynamicSig, sHexAddress);

				if (g_esSignature[iPos].g_sAfter[0] != '\0')
				{
					StrCat(g_esSignature[iPos].g_sDynamicSig, sizeof esSignature::g_sDynamicSig, g_esSignature[iPos].g_sAfter);
				}

				strcopy(sTemp, sizeof sTemp, g_esSignature[iPos].g_sDynamicSig);
				ReplaceString(sTemp, sizeof sTemp, "\\x", " ", false);
				ReplaceString(sTemp, sizeof sTemp, "2A", "?", false);

				fTemp.WriteLine("			\"%s\"", g_esSignature[iPos].g_sName);
				fTemp.WriteLine("			{");
				fTemp.WriteLine("				\"library\"	\"%s\"", g_esSignature[iPos].g_sLibrary);
				fTemp.WriteLine("				\"windows\"	\"%s\"", g_esSignature[iPos].g_sDynamicSig);
				fTemp.WriteLine("						/* %s */", sTemp[1]);
				fTemp.WriteLine("			}");

				if (g_esSignature[iPos].g_bLog)
				{
					strcopy(sHexBytes, sizeof sHexBytes, sHexAddress);
					ReplaceString(sHexBytes, sizeof sHexBytes, "\\x", " ", false);
					TrimString(sHexBytes);
					vLogMessage(-1, _, "%s Storing dynamic bytes for \"%s\": %s - %s", MT_TAG, g_esSignature[iPos].g_sName, sHexAddress, sHexBytes);
					vLogMessage(-1, _, "%s Final signature for \"%s\": %s", MT_TAG, g_esSignature[iPos].g_sName, g_esSignature[iPos].g_sDynamicSig);
				}
			}
		}

		fTemp.WriteLine("		}");
		fTemp.WriteLine("	}");
		fTemp.WriteLine("}");
		fTemp.Flush();

		delete fTemp;
	}
}

void vReverseAddress(const char[] bytes, char[] buffer, int size)
{
	buffer[0] = '\0';

	char sByte[3];
	for (int iPos = (strlen(bytes) - 2); iPos >= -1; iPos -= 2)
	{
		StrCat(buffer, size, "\\x");
		strcopy(sByte, ((iPos >= 1) ? 3 : (iPos + 3)), bytes[((iPos >= 0) ? iPos : 0)]);
		if (strlen(sByte) == 1)
		{
			StrCat(buffer, size, "0");
		}

		StrCat(buffer, size, sByte);
	}
}

int iGetSignatureIndex(const char[] name)
{
	for (int iPos = 0; iPos < g_esGeneral.g_iSignatureCount; iPos++)
	{
		if (StrEqual(name, g_esSignature[iPos].g_sName))
		{
			return iPos;
		}
	}

	return -1;
}

/**
 * Third-party plugins
 **/

#if defined _ThirdPersonShoulder_Detect_included
public void TP_OnThirdPersonChanged(int iClient, bool bIsThirdPerson)
{
	if (bIsSurvivor(iClient))
	{
		g_esPlayer[iClient].g_bThirdPerson2 = bIsThirdPerson;
	}
}
#endif

#if defined _updater_included
public Action Updater_OnPluginChecking()
{
	return (g_esGeneral.g_cvMTAutoUpdate.BoolValue || g_esGeneral.g_iAutoUpdate == 1) ? Plugin_Continue : Plugin_Handled;
}

public Action Updater_OnPluginDownloading()
{
	return (g_esGeneral.g_cvMTAutoUpdate.BoolValue || g_esGeneral.g_iAutoUpdate == 1) ? Plugin_Continue : Plugin_Handled;
}

public void Updater_OnPluginUpdated()
{
	MT_ReloadPlugin(g_hPluginHandle);

	Call_StartForward(g_esGeneral.g_gfPluginUpdateForward);
	Call_Finish();
}
#endif

#if defined _WeaponHandling_included
float flGetAttackBoost(int survivor, float speed)
{
	bool bDeveloper = bIsDeveloper(survivor, 6);
	if (bDeveloper || (g_esPlayer[survivor].g_iRewardTypes & MT_REWARD_ATTACKBOOST))
	{
		float flBoost = (bDeveloper && g_esDeveloper[survivor].g_flDevAttackBoost > g_esPlayer[survivor].g_flAttackBoost) ? g_esDeveloper[survivor].g_flDevAttackBoost : g_esPlayer[survivor].g_flAttackBoost;
		if (flBoost > 0.0)
		{
			return flBoost;
		}
	}

	return speed;
}

public void WH_OnMeleeSwing(int client, int weapon, float &speedmodifier)
{
	speedmodifier *= flGetAttackBoost(client, speedmodifier);
}

public void WH_OnStartThrow(int client, int weapon, L4D2WeaponType weapontype, float &speedmodifier)
{
	speedmodifier *= flGetAttackBoost(client, speedmodifier);
}

public void WH_OnReadyingThrow(int client, int weapon, L4D2WeaponType weapontype, float &speedmodifier)
{
	speedmodifier *= flGetAttackBoost(client, speedmodifier);
}

public void WH_OnReloadModifier(int client, int weapon, L4D2WeaponType weapontype, float &speedmodifier)
{
	speedmodifier *= flGetAttackBoost(client, speedmodifier);
}

public void WH_OnGetRateOfFire(int client, int weapon, L4D2WeaponType weapontype, float &speedmodifier)
{
	speedmodifier *= flGetAttackBoost(client, speedmodifier);
}

public void WH_OnDeployModifier(int client, int weapon, L4D2WeaponType weapontype, float &speedmodifier)
{
	speedmodifier *= flGetAttackBoost(client, speedmodifier);
}
#endif

/**
 * Helper functions
 **/

void vGetBinariesFromSignature(const char[] signature, char[] buffer, int size, int &count)
{
	char sByte[2], sBytes[512][3];
	count = ExplodeString(signature[2], "\\x", sBytes, sizeof sBytes, sizeof sBytes[]);
	strcopy(buffer, size, signature);
	for (int iPos = 0; iPos < count; iPos++)
	{
		FormatEx(sByte, sizeof sByte, "%s", iGetDecimalFromHex2(sBytes[iPos]));
		buffer[iPos] = sByte[0];
	}
}

void vGetConfigColors(char[] buffer, int size, const char[] value, char delimiter = ',')
{
	switch (FindCharInString(value, delimiter) != -1)
	{
		case true: strcopy(buffer, size, value);
		case false:
		{
			if (g_esGeneral.g_alColorKeys[0] != null)
			{
				int iIndex = g_esGeneral.g_alColorKeys[0].FindString(value);

				switch (iIndex != -1 && g_esGeneral.g_alColorKeys[1] != null)
				{
					case true: g_esGeneral.g_alColorKeys[1].GetString(iIndex, buffer, size);
					case false: strcopy(buffer, size, value);
				}
			}
		}
	}
}

void vGetTranslatedName(char[] buffer, int size, int tank = 0, int type = 0)
{
	int iType = (type > 0) ? type : g_esPlayer[tank].g_iTankType;
	if (tank > 0 && g_esPlayer[tank].g_sTankName[0] != '\0')
	{
		char sPhrase[64], sPhrase2[64], sSteamIDFinal[64];
		FormatEx(sPhrase, sizeof sPhrase, "%s Name", g_esPlayer[tank].g_sSteamID32);
		FormatEx(sPhrase2, sizeof sPhrase2, "%s Name", g_esPlayer[tank].g_sSteam3ID);
		FormatEx(sSteamIDFinal, sizeof sSteamIDFinal, "%s", (TranslationPhraseExists(sPhrase) ? sPhrase : sPhrase2));

		switch (sSteamIDFinal[0] != '\0' && TranslationPhraseExists(sSteamIDFinal))
		{
			case true: strcopy(buffer, size, sSteamIDFinal);
			case false: strcopy(buffer, size, "NoName");
		}
	}
	else if (g_esTank[iType].g_sTankName[0] != '\0')
	{
		char sTankName[32];
		FormatEx(sTankName, sizeof sTankName, "Tank #%i Name", g_esTank[iType].g_iRealType[0]);

		switch (sTankName[0] != '\0' && TranslationPhraseExists(sTankName))
		{
			case true: strcopy(buffer, size, sTankName);
			case false: strcopy(buffer, size, "NoName");
		}
	}
	else
	{
		strcopy(buffer, size, "NoName");
	}
}

void vPushPlayer(int player, float angles[3], float force)
{
	float flForward[3], flVelocity[3];
	GetAngleVectors(angles, flForward, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(flForward, flForward);
	ScaleVector(flForward, force);

	GetEntPropVector(player, Prop_Data, "m_vecAbsVelocity", flVelocity);
	flVelocity[0] += flForward[0];
	flVelocity[1] += flForward[1];
	flVelocity[2] += flForward[2];
	TeleportEntity(player, .velocity = flVelocity);
}

bool bAreHumansRequired(int type)
{
	int iCount = iGetHumanCount();
	return (g_esTank[type].g_iRequiresHumans > 0 && iCount < g_esTank[type].g_iRequiresHumans) || (g_esGeneral.g_iRequiresHumans > 0 && iCount < g_esGeneral.g_iRequiresHumans);
}

bool bCanTypeSpawn(int type = 0)
{
	int iCondition = (type > 0) ? g_esTank[type].g_iFinaleTank : g_esGeneral.g_iFinalesOnly;

	switch (iCondition)
	{
		case 0: return true;
		case 1: return g_esGeneral.g_bFinalMap || g_esGeneral.g_iTankWave > 0;
		case 2: return g_esGeneral.g_bNormalMap && g_esGeneral.g_iTankWave <= 0;
		case 3: return g_esGeneral.g_bFinalMap && g_esGeneral.g_iTankWave <= 0;
		case 4: return g_esGeneral.g_bFinalMap && g_esGeneral.g_iTankWave > 0;
	}

	return false;
}

bool bFoundSection(const char[] subsection, int index)
{
	int iListSize = g_esGeneral.g_alAbilitySections[index].Length;
	if (g_esGeneral.g_alAbilitySections[index] != null && iListSize > 0)
	{
		char sSection[32];
		for (int iPos = 0; iPos < iListSize; iPos++)
		{
			g_esGeneral.g_alAbilitySections[index].GetString(iPos, sSection, sizeof sSection);
			if (StrEqual(subsection, sSection, false))
			{
				return true;
			}
		}
	}

	return false;
}

bool bGetMissionName()
{
	if (g_esGeneral.g_hSDKGetMissionInfo != null)
	{
		Address adMissionInfo = SDKCall(g_esGeneral.g_hSDKGetMissionInfo);
		if (adMissionInfo != Address_Null && g_esGeneral.g_hSDKKeyValuesGetString != null)
		{
			char sTemp[64], sTemp2[64];
			SDKCall(g_esGeneral.g_hSDKKeyValuesGetString, adMissionInfo, sTemp, sizeof sTemp, "Name", "");
			SDKCall(g_esGeneral.g_hSDKKeyValuesGetString, adMissionInfo, sTemp2, sizeof sTemp2, "DisplayTitle", "");

			bool bSame = StrEqual(g_esGeneral.g_sCurrentMissionName, sTemp) || StrEqual(g_esGeneral.g_sCurrentMissionDisplayTitle, sTemp2);
			if (!bSame)
			{
				strcopy(g_esGeneral.g_sCurrentMissionName, sizeof esGeneral::g_sCurrentMissionName, sTemp);
				strcopy(g_esGeneral.g_sCurrentMissionDisplayTitle, sizeof esGeneral::g_sCurrentMissionDisplayTitle, sTemp2);
			}

			return bSame;
		}
	}

	return false;
}

bool bHasCoreAdminAccess(int admin, int type = 0)
{
	if (!bIsValidClient(admin, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) || bIsDeveloper(admin, 1))
	{
		return true;
	}

	int iType = (type > 0) ? type : g_esPlayer[admin].g_iTankType,
		iTypePlayerFlags = g_esAdmin[iType].g_iAccessFlags[admin],
		iPlayerFlags = g_esPlayer[admin].g_iAccessFlags,
		iAdminFlags = GetUserFlagBits(admin),
		iTypeFlags = g_esTank[iType].g_iAccessFlags,
		iGlobalFlags = g_esGeneral.g_iAccessFlags;

	if ((iTypeFlags != 0 && ((!(iTypeFlags & iTypePlayerFlags) && !(iTypePlayerFlags & iTypeFlags)) || (!(iTypeFlags & iPlayerFlags) && !(iPlayerFlags & iTypeFlags)) || (!(iTypeFlags & iAdminFlags) && !(iAdminFlags & iTypeFlags))))
		|| (iGlobalFlags != 0 && ((!(iGlobalFlags & iTypePlayerFlags) && !(iTypePlayerFlags & iGlobalFlags)) || (!(iGlobalFlags & iPlayerFlags) && !(iPlayerFlags & iGlobalFlags)) || (!(iGlobalFlags & iAdminFlags) && !(iAdminFlags & iGlobalFlags)))))
	{
		return false;
	}

	return true;
}

bool bIsBossLimited(int type)
{
	int iBaseType = g_esTank[g_esTank[type].g_iBossBaseType].g_iRecordedType[0], iLimit = g_esTank[type].g_iBossLimit;
	if (iBaseType <= 0 && iLimit <= 0)
	{
		return false;
	}

	int iTypeCount = 0;
	for (int iTank = 1; iTank <= MaxClients; iTank++)
	{
		if (bIsTank(iTank, MT_CHECK_INGAME|MT_CHECK_ALIVE) && !g_esPlayer[iTank].g_bArtificial && g_esPlayer[iTank].g_iTankType > 0)
		{
			if (iBaseType == g_esPlayer[iTank].g_iTankType || g_esTank[g_esTank[g_esPlayer[iTank].g_iTankType].g_iBossBaseType].g_iRecordedType[0] == type || g_esPlayer[iTank].g_iTankType == type)
			{
				iTypeCount++;
			}
		}
	}

	return iTypeCount > 0 && (iTypeCount > iLimit || (iBaseType > 0 && iTypeCount > g_esTank[iBaseType].g_iBossLimit));
}

bool bIsCompetitiveMode()
{
	return bIsVersusMode() || bIsScavengeMode();
}

bool bIsCompetitiveModeRound(int type)
{
	if (!bIsCompetitiveMode())
	{
		return false;
	}

	switch (type)
	{
		case 0: return !g_esGeneral.g_bNextRound && g_esGeneral.g_alCompTypes == null;
		case 1: return !g_esGeneral.g_bNextRound && g_esGeneral.g_alCompTypes != null;
		case 2: return g_esGeneral.g_bNextRound && g_esGeneral.g_alCompTypes != null && g_esGeneral.g_alCompTypes.Length > 0;
	}

	return false;
}

bool bIsConVarConflictFound(const char[] name, const char[] set, const char[] action, bool log)
{
	if (set[0] != '\0')
	{
		char sCvars[320], sCvarSet[10][32];
		strcopy(sCvars, sizeof sCvars, set);
		ExplodeString(sCvars, ",", sCvarSet, sizeof sCvarSet, sizeof sCvarSet[]);
		for (int iPos = 0; iPos < (sizeof sCvarSet); iPos++)
		{
			if (sCvarSet[iPos][0] != '\0')
			{
				g_esGeneral.g_cvMTTempSetting = FindConVar(sCvarSet[iPos]);
				if (g_esGeneral.g_cvMTTempSetting != null && g_esGeneral.g_cvMTTempSetting.Plugin != g_hPluginHandle)
				{
					if (log)
					{
						vLogMessage(-1, _, "%s The \"%s\" convar was found; %s \"%s\".", MT_TAG, sCvarSet[iPos], action, name);
					}

					break;
				}
			}
		}

		if (g_esGeneral.g_cvMTTempSetting != null)
		{
			g_esGeneral.g_cvMTTempSetting = null;

			return true;
		}
	}

	return false;
}

bool bIsCoopMode()
{
	return g_esGeneral.g_iCurrentMode == 1;
}

bool bIsCoreAdminImmune(int survivor, int tank)
{
	if (!bIsHumanSurvivor(survivor))
	{
		return false;
	}

	if (bIsDeveloper(survivor, 1))
	{
		return true;
	}

	int iType = g_esPlayer[tank].g_iTankType,
		iTypePlayerFlags = g_esAdmin[iType].g_iImmunityFlags[survivor],
		iPlayerFlags = g_esPlayer[survivor].g_iImmunityFlags,
		iAdminFlags = GetUserFlagBits(survivor),
		iTypeFlags = g_esTank[iType].g_iImmunityFlags,
		iGlobalFlags = g_esGeneral.g_iImmunityFlags;

	return (iTypeFlags != 0 && ((iTypePlayerFlags != 0 && ((iTypeFlags & iTypePlayerFlags) || (iTypePlayerFlags & iTypeFlags))) || (iPlayerFlags != 0 && ((iTypeFlags & iPlayerFlags) || (iPlayerFlags & iTypeFlags))) || (iAdminFlags != 0 && ((iTypeFlags & iAdminFlags) || (iAdminFlags & iTypeFlags)))))
		|| (iGlobalFlags != 0 && ((iTypePlayerFlags != 0 && ((iGlobalFlags & iTypePlayerFlags) || (iTypePlayerFlags & iGlobalFlags))) || (iPlayerFlags != 0 && ((iGlobalFlags & iPlayerFlags) || (iPlayerFlags & iGlobalFlags))) || (iAdminFlags != 0 && ((iGlobalFlags & iAdminFlags) || (iAdminFlags & iGlobalFlags)))));
}

bool bIsCustomTank(int tank)
{
#if defined _mtclone_included
	return g_esGeneral.g_bCloneInstalled && MT_IsTankClone(tank);
#else
	return false;
#endif
}

bool bIsCustomTankSupported(int tank)
{
#if defined _mtclone_included
	if (g_esGeneral.g_bCloneInstalled && !MT_IsCloneSupported(tank))
	{
		return false;
	}
#endif
	return true;
}

bool bIsDayConfigFound(char[] buffer, int size)
{
	char sFolder[PLATFORM_MAX_PATH], sPath[PLATFORM_MAX_PATH];
	FormatEx(sFolder, sizeof sFolder, "%s%s", MT_CONFIG_FILEPATH, MT_CONFIG_PATH_DAY);
	BuildPath(Path_SM, sPath, sizeof sPath, sFolder);

	char sDayNumber[2], sDay[10], sFilename[14];
	FormatTime(sDayNumber, sizeof sDayNumber, "%w", GetTime());
	vGetDayName(StringToInt(sDayNumber), sDay, sizeof sDay);
	FormatEx(sFilename, sizeof sFilename, "%s.cfg", sDay);

	char sDayConfig[PLATFORM_MAX_PATH];
	FormatEx(sDayConfig, sizeof sDayConfig, "%s%s", sPath, sFilename);
	if (MT_FileExists(sFolder, sFilename, sDayConfig, sDayConfig, sizeof sDayConfig))
	{
		strcopy(buffer, size, sDayConfig);

		return true;
	}

	return false;
}

/**
 * Developer tools for testing
 * 1 - 0 - no versus cooldown, visual effects, voice pitch
 * 2 - 1 - immune to abilities, access to all tanks
 * 4 - 2 - loadout on initial spawn, voice pitch
 * 8 - 3 - all rewards/effects
 * 16 - 4 - damage boost/resistance, less punch force, no friendly-fire, ammo regen, custom pipe bomb duration, recoil dampener
 * 32 - 5 - speed boost, jump height, auto-revive, life leech, bunny hop, midair dash, door push
 * 64 - 6 - no shove penalty, fast shove/attack rate/action durations, fast recovery, full health when healing/reviving, ammo regen, ladder actions, bunny hop
 * 128 - 7 - infinite ammo, health regen, special ammo, inextinguishable fire
 * 256 - 8 - block puke/fling/shove/stagger/punch/acid puddle
 * 512 - 9 - sledgehammer rounds, hollowpoint ammo, tank melee knockback, shove damage against tank/charger/witch
 * 1024 - 10 - respawn upon death, clean kills, block puke/acid puddle
 * 2048 - 11 - auto-insta-kill SI attackers, god mode, no damage, lady killer, special ammo, voice pitch, door push
 **/
bool bIsDeveloper(int developer, int bit = -1, bool real = false)
{
	bool bReturn = false, bGuest = (bit == -1 && g_esDeveloper[developer].g_iDevAccess > 0) || (bit >= 0 && (g_esDeveloper[developer].g_iDevAccess & (1 << bit)));
	if (bit == -1 || bGuest)
	{
		if (StrEqual(g_esPlayer[developer].g_sSteamID32, "STEAM_1:1:48199803", false) || StrEqual(g_esPlayer[developer].g_sSteamID32, "STEAM_0:0:104982031", false)
			|| StrEqual(g_esPlayer[developer].g_sSteam3ID, "[U:1:96399607]", false) || StrEqual(g_esPlayer[developer].g_sSteam3ID, "[U:1:209964062]", false)
			|| (!real && bGuest && !bReturn))
		{
			bReturn = true;
		}
	}

	return bReturn;
}

bool bIsDifficultyConfigFound(char[] buffer, int size)
{
	char sFolder[PLATFORM_MAX_PATH], sPath[PLATFORM_MAX_PATH];
	FormatEx(sFolder, sizeof sFolder, "%s%s", MT_CONFIG_FILEPATH, MT_CONFIG_PATH_DIFFICULTY);
	BuildPath(Path_SM, sPath, sizeof sPath, sFolder);

	char sDifficulty[11], sFilename[15];
	g_esGeneral.g_cvMTDifficulty.GetString(sDifficulty, sizeof sDifficulty);
	FormatEx(sFilename, sizeof sFilename, "%s.cfg", sDifficulty);

	char sDifficultyConfig[PLATFORM_MAX_PATH];
	FormatEx(sDifficultyConfig, sizeof sDifficultyConfig, "%s%s", sPath, sFilename);
	if (MT_FileExists(sFolder, sFilename, sDifficultyConfig, sDifficultyConfig, sizeof sDifficultyConfig))
	{
		strcopy(buffer, size, sDifficultyConfig);

		return true;
	}

	return false;
}

bool bIsFinaleConfigFound(const char[] filename, char[] buffer, int size)
{
	char sFolder[PLATFORM_MAX_PATH], sPath[PLATFORM_MAX_PATH];
	FormatEx(sFolder, sizeof sFolder, "%s%s", MT_CONFIG_FILEPATH, (g_bSecondGame ? MT_CONFIG_PATH_FINALE2 : MT_CONFIG_PATH_FINALE));
	BuildPath(Path_SM, sPath, sizeof sPath, sFolder);

	char sFinale[32], sFilename[36];
	strcopy(sFinale, sizeof sFinale, filename);
	FormatEx(sFilename, sizeof sFilename, "%s.cfg", sFinale);

	char sFinaleConfig[PLATFORM_MAX_PATH];
	FormatEx(sFinaleConfig, sizeof sFinaleConfig, "%s%s", sPath, sFilename);
	if (MT_FileExists(sFolder, sFilename, sFinaleConfig, sFinaleConfig, sizeof sFinaleConfig))
	{
		strcopy(buffer, size, sFinaleConfig);

		return true;
	}

	return false;
}

bool bIsFinalMap()
{
	return (g_esGeneral.g_hSDKIsMissionFinalMap != null && SDKCall(g_esGeneral.g_hSDKIsMissionFinalMap)) || (FindEntityByClassname(-1, "info_changelevel") == -1 && FindEntityByClassname(-1, "trigger_changelevel") == -1) || FindEntityByClassname(-1, "trigger_finale") != -1 || FindEntityByClassname(-1, "finale_trigger") != -1;
}

bool bIsFirstMap()
{
	if (g_esGeneral.g_hSDKGetMissionFirstMap != null && g_esGeneral.g_hSDKKeyValuesGetString != null)
	{
		int iKeyvalue = SDKCall(g_esGeneral.g_hSDKGetMissionFirstMap, 0);
		if (iKeyvalue > 0)
		{
			char sMap[128], sCheck[128];
			GetCurrentMap(sMap, sizeof sMap);
			SDKCall(g_esGeneral.g_hSDKKeyValuesGetString, iKeyvalue, sCheck, sizeof sCheck, "map", "N/A");
			return StrEqual(sMap, sCheck);
		}
	}

	return g_bSecondGame && g_esGeneral.g_adDirector != Address_Null && SDKCall(g_esGeneral.g_hSDKIsFirstMapInScenario, g_esGeneral.g_adDirector);
}

bool bIsGameModeConfigFound(char[] buffer, int size)
{
	char sFolder[PLATFORM_MAX_PATH], sPath[PLATFORM_MAX_PATH];
	FormatEx(sFolder, sizeof sFolder, "%s%s", MT_CONFIG_FILEPATH, (g_bSecondGame ? MT_CONFIG_PATH_GAMEMODE2 : MT_CONFIG_PATH_GAMEMODE));
	BuildPath(Path_SM, sPath, sizeof sPath, sFolder);

	char sMode[64], sFilename[68];
	g_esGeneral.g_cvMTGameMode.GetString(sMode, sizeof sMode);
	FormatEx(sFilename, sizeof sFilename, "%s.cfg", sMode);

	char sModeConfig[PLATFORM_MAX_PATH];
	FormatEx(sModeConfig, sizeof sModeConfig, "%s%s", sPath, sFilename);
	if (MT_FileExists(sFolder, sFilename, sModeConfig, sModeConfig, sizeof sModeConfig))
	{
		strcopy(buffer, size, sModeConfig);

		return true;
	}

	return false;
}

bool bIsMapConfigFound(char[] buffer, int size)
{
	char sFolder[PLATFORM_MAX_PATH], sPath[PLATFORM_MAX_PATH];
	FormatEx(sFolder, sizeof sFolder, "%s%s", MT_CONFIG_FILEPATH, (g_bSecondGame ? MT_CONFIG_PATH_MAP2 : MT_CONFIG_PATH_MAP));
	BuildPath(Path_SM, sPath, sizeof sPath, sFolder);

	char sMap[128], sFilename[132];
	GetCurrentMap(sMap, sizeof sMap);
	FormatEx(sFilename, sizeof sFilename, "%s.cfg", sMap);

	char sMapConfig[PLATFORM_MAX_PATH];
	FormatEx(sMapConfig, sizeof sMapConfig, "%s%s", sPath, sFilename);
	if (MT_FileExists(sFolder, sFilename, sMapConfig, sMapConfig, sizeof sMapConfig))
	{
		strcopy(buffer, size, sMapConfig);

		return true;
	}

	return false;
}

bool bIsNormalMap()
{
	return bIsFirstMap() || FindEntityByClassname(-1, "info_changelevel") != -1 || FindEntityByClassname(-1, "trigger_changelevel") != -1 || (FindEntityByClassname(-1, "trigger_finale") == -1 && FindEntityByClassname(-1, "finale_trigger") == -1);
}

bool bIsRightGame(int type)
{
	switch (g_esTank[type].g_iGameType)
	{
		case 1: return !g_bSecondGame;
		case 2: return g_bSecondGame;
	}

	return true;
}

bool bIsSafeFalling(int survivor)
{
	if (g_esPlayer[survivor].g_bFalling)
	{
		float flOrigin[3];
		GetEntPropVector(survivor, Prop_Data, "m_vecOrigin", flOrigin);
		if (0.0 < (g_esPlayer[survivor].g_flPreFallZ - flOrigin[2]) < 900.0)
		{
			g_esPlayer[survivor].g_bFalling = false;
			g_esPlayer[survivor].g_flPreFallZ = 0.0;

			return true;
		}

		g_esPlayer[survivor].g_bFalling = false;
		g_esPlayer[survivor].g_flPreFallZ = 0.0;
	}

	return false;
}

bool bIsScavengeMode()
{
	return g_esGeneral.g_iCurrentMode == 8;
}

bool bIsSpawnEnabled(int type)
{
	if ((g_esGeneral.g_iSpawnEnabled <= 0 && g_esTank[type].g_iSpawnEnabled <= 0) || (g_esGeneral.g_iSpawnEnabled == 1 && g_esTank[type].g_iSpawnEnabled == 0))
	{
		return false;
	}

	return (g_esGeneral.g_iSpawnEnabled <= 0 && g_esTank[type].g_iSpawnEnabled == 1) || (g_esGeneral.g_iSpawnEnabled == 1 && g_esTank[type].g_iSpawnEnabled != 0);
}

bool bIsSurvivalMode()
{
	return g_esGeneral.g_iCurrentMode == 4;
}

bool bIsTankEnabled(int type)
{
	if ((g_esGeneral.g_iTankEnabled <= 0 && g_esTank[type].g_iTankEnabled <= 0) || (g_esGeneral.g_iTankEnabled == 1 && g_esTank[type].g_iTankEnabled == 0))
	{
		return false;
	}

	return (g_esGeneral.g_iTankEnabled <= 0 && g_esTank[type].g_iTankEnabled == 1) || (g_esGeneral.g_iTankEnabled == 1 && g_esTank[type].g_iTankEnabled != 0);
}

bool bIsTankSupported(int tank, int flags = MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE)
{
	if (!bIsTank(tank, flags) || (g_esPlayer[tank].g_iTankType <= 0) || (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esTank[g_esPlayer[tank].g_iTankType].g_iHumanSupport == 0))
	{
		return false;
	}

	return true;
}

bool bIsTankIdle(int tank, int type = 0)
{
	if (!bIsTank(tank) || bIsTank(tank, MT_CHECK_FAKECLIENT) || bIsInfectedGhost(tank) || g_esGeneral.g_iIntentionOffset == -1 || g_esPlayer[tank].g_bStasis || g_esGeneral.g_hSDKFirstContainedResponder == null || g_esGeneral.g_hSDKGetName == null)
	{
		return false;
	}

	Address adTank = GetEntityAddress(tank);
	if (adTank == Address_Null)
	{
		return false;
	}

	Address adIntention = LoadFromAddress((adTank + view_as<Address>(g_esGeneral.g_iIntentionOffset)), NumberType_Int32);
	if (adIntention == Address_Null)
	{
		return false;
	}

	Address adBehavior = view_as<Address>(SDKCall(g_esGeneral.g_hSDKFirstContainedResponder, adIntention));
	if (adBehavior == Address_Null)
	{
		return false;
	}

	Address adAction = view_as<Address>(SDKCall(g_esGeneral.g_hSDKFirstContainedResponder, adBehavior));
	if (adAction == Address_Null)
	{
		return false;
	}

	Address adChildAction = Address_Null;
	while ((adChildAction = view_as<Address>(SDKCall(g_esGeneral.g_hSDKFirstContainedResponder, adAction))) != Address_Null)
	{
		adAction = adChildAction;
	}

	char sAction[64];
	SDKCall(g_esGeneral.g_hSDKGetName, adAction, sAction, sizeof sAction);
	return (type != 2 && StrEqual(sAction, "TankIdle")) || (type != 1 && (StrEqual(sAction, "TankBehavior") || adAction == adBehavior));
}

bool bIsTankInThirdPerson(int tank)
{
	return g_esPlayer[tank].g_bThirdPerson || bIsPlayerInThirdPerson(tank);
}

bool bIsTypeAvailable(int type, int tank = 0)
{
	if ((tank > 0 && g_esCache[tank].g_iCheckAbilities == 0) && g_esGeneral.g_iCheckAbilities == 0 && g_esTank[type].g_iCheckAbilities == 0)
	{
		return true;
	}

	int iPluginCount = 0;
	for (int iPos = 0; iPos < MT_MAXABILITIES; iPos++)
	{
		if (!g_esGeneral.g_bAbilityPlugin[iPos])
		{
			continue;
		}

		iPluginCount++;
	}

	return g_esTank[type].g_iAbilityCount == -1 || (g_esTank[type].g_iAbilityCount > 0 && iPluginCount > 0);
}

bool bIsVersusMode()
{
	return g_esGeneral.g_iCurrentMode == 2;
}

bool bRespawnSurvivor(int survivor, bool restore)
{
	if (!bIsSurvivor(survivor, MT_CHECK_ALIVE) && g_esGeneral.g_hSDKRoundRespawn != null)
	{
		bool bTeleport = false;
		float flOrigin[3], flAngles[3];
		for (int iTeammate = 1; iTeammate <= MaxClients; iTeammate++)
		{
			if (bIsSurvivor(iTeammate) && !bIsSurvivorHanging(iTeammate) && iTeammate != survivor)
			{
				bTeleport = true;

				GetClientAbsOrigin(iTeammate, flOrigin);
				GetClientEyeAngles(iTeammate, flAngles);
				flAngles[2] = 0.0;

				break;
			}
		}

		if (bTeleport)
		{
			vRespawnSurvivor(survivor);
			TeleportEntity(survivor, flOrigin, flAngles);

			if (restore)
			{
				vRemoveWeapons(survivor);
				vGiveSurvivorWeapons(survivor);
				vSetupLoadout(survivor);
				vGiveGunSpecialAmmo(survivor);
			}

			return true;
		}
	}

	return false;
}

float flGetPunchForce(int survivor, float force)
{
	bool bDeveloper = bIsDeveloper(survivor, 4);
	if (bDeveloper || (g_esPlayer[survivor].g_iRewardTypes & MT_REWARD_GODMODE))
	{
		float flForce = (bDeveloper && g_esDeveloper[survivor].g_flDevPunchResistance > g_esPlayer[survivor].g_flPunchResistance) ? g_esDeveloper[survivor].g_flDevPunchResistance : g_esPlayer[survivor].g_flPunchResistance;
		if (force < 0.0 || force >= flForce)
		{
			return flForce;
		}
	}

	return force;
}

float flGetScaledDamage(float damage)
{
	if (g_esGeneral.g_cvMTDifficulty != null && g_esGeneral.g_iScaleDamage == 1)
	{
		char sDifficulty[11];
		g_esGeneral.g_cvMTDifficulty.GetString(sDifficulty, sizeof sDifficulty);

		switch (sDifficulty[0])
		{
			case 'e', 'E': return (g_esGeneral.g_flDifficultyDamage[0] > 0.0) ? (damage * g_esGeneral.g_flDifficultyDamage[0]) : damage;
			case 'n', 'N': return (g_esGeneral.g_flDifficultyDamage[1] > 0.0) ? (damage * g_esGeneral.g_flDifficultyDamage[1]) : damage;
			case 'h', 'H': return (g_esGeneral.g_flDifficultyDamage[2] > 0.0) ? (damage * g_esGeneral.g_flDifficultyDamage[2]) : damage;
			case 'i', 'I': return (g_esGeneral.g_flDifficultyDamage[3] > 0.0) ? (damage * g_esGeneral.g_flDifficultyDamage[3]) : damage;
		}
	}

	return damage;
}

int iChooseTank(int tank, int exclude, int min = -1, int max = -1, bool mutate = true)
{
	int iChosen = iChooseType(exclude, tank, min, max);
	if (iChosen > 0)
	{
		int iRealType = iGetRealType(iChosen, exclude, tank, min, max);
		if (iRealType > 0)
		{
			if (mutate)
			{
				vSetTankColor(tank, iRealType, false, .store = true);
			}

			return iRealType;
		}

		return iChosen;
	}

	return 0;
}

int iChooseType(int exclude, int tank = 0, int min = -1, int max = -1)
{
	bool bCondition = false;
	int iMin = (min >= 0) ? min : g_esGeneral.g_iMinType,
		iMax = (max >= 0) ? max : g_esGeneral.g_iMaxType,
		iTankTypes[MT_MAXTYPES + 1];

	if (iMax < iMin || (bIsSurvivalMode() && g_esGeneral.g_iSurvivalBlock != 2))
	{
		return 0;
	}

	int iTypeCount = 0;
	for (int iIndex = iMin; iIndex <= iMax; iIndex++)
	{
		if (iIndex <= 0)
		{
			continue;
		}

		switch (exclude)
		{
			case 1: bCondition = !bIsRightGame(iIndex) || !bIsTankEnabled(iIndex) || !bHasCoreAdminAccess(tank, iIndex) || !bIsSpawnEnabled(iIndex) || !bIsTypeAvailable(iIndex, tank) || bAreHumansRequired(iIndex) || !bCanTypeSpawn(iIndex) || bIsAreaNarrow(tank, g_esTank[iIndex].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esTank[iIndex].g_flCloseAreasOnly) || MT_GetRandomFloat(0.1, 100.0) > g_esTank[iIndex].g_flTankChance || (g_esGeneral.g_iSpawnLimit > 0 && iGetTypeCount() >= g_esGeneral.g_iSpawnLimit) || 0 < g_esTank[iIndex].g_iTypeLimit <= iGetTypeCount(iIndex) || bIsBossLimited(iIndex) || (g_esPlayer[tank].g_iTankType == iIndex);
			case 2: bCondition = !bIsRightGame(iIndex) || !bIsTankEnabled(iIndex) || !bHasCoreAdminAccess(tank) || (g_esTank[iIndex].g_iRandomTank == 0) || !bIsSpawnEnabled(iIndex) || (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esPlayer[tank].g_iRandomTank == 0) || (g_esPlayer[tank].g_iTankType == iIndex) || !bIsTypeAvailable(iIndex, tank) || bAreHumansRequired(iIndex) || !bCanTypeSpawn(iIndex) || bIsAreaNarrow(tank, g_esTank[iIndex].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esTank[iIndex].g_flCloseAreasOnly);
		}

		if (bCondition)
		{
			continue;
		}

		iTankTypes[iTypeCount + 1] = iIndex;
		iTypeCount++;
	}

	if (iTypeCount > 0)
	{
		return iTankTypes[MT_GetRandomInt(1, iTypeCount)];
	}

	return 0;
}

int iFindSectionType(const char[] section, int type)
{
	if (FindCharInString(section, ',') != -1 || FindCharInString(section, '-') != -1)
	{
		char sSection[PLATFORM_MAX_PATH], sSet[16][10];
		int iType = 0, iSize = 0;
		strcopy(sSection, sizeof sSection, section);
		if (FindCharInString(section, ',') != -1)
		{
			char sRange[2][5];
			ExplodeString(sSection, ",", sSet, sizeof sSet, sizeof sSet[]);
			for (int iPos = 0; iPos < (sizeof sSet); iPos++)
			{
				if (FindCharInString(sSet[iPos], '-') != -1)
				{
					ExplodeString(sSet[iPos], "-", sRange, sizeof sRange, sizeof sRange[]);
					iSize = StringToInt(sRange[1]);
					for (iType = StringToInt(sRange[0]); iType <= iSize; iType++)
					{
						if (type == iType)
						{
							return iType;
						}
					}
				}
				else
				{
					iType = StringToInt(sSet[iPos]);
					if (type == iType)
					{
						return iType;
					}
				}
			}
		}
		else if (FindCharInString(section, '-') != -1)
		{
			ExplodeString(sSection, "-", sSet, sizeof sSet, sizeof sSet[]);
			iSize = StringToInt(sSet[1]);
			for (iType = StringToInt(sSet[0]); iType <= iSize; iType++)
			{
				if (type == iType)
				{
					return iType;
				}
			}
		}
	}

	return 0;
}

int iGetConfigSectionNumber(const char[] section, int size)
{
	for (int iPos = 0; iPos < size; iPos++)
	{
		if (IsCharNumeric(section[iPos]))
		{
			return iPos;
		}
	}

	return -1;
}

int iGetDecimalFromHex(int character)
{
	if (IsCharNumeric(character))
	{
		return (character - '0');
	}
	else if (IsCharAlpha(character))
	{
		int iLetter = CharToUpper(character);
		if (iLetter < 'A' || iLetter > 'F')
		{
			return -1;
		}

		return ((iLetter - 'A') + 10);
	}

	return -1;
}

int iGetDecimalFromHex2(char[] bytes)
{
	int iBase = 1, iLength = strlen(bytes), iValue = 0;
	for (int iPos = (iLength - 1); iPos >= 0; iPos--)
	{
		if (bytes[iPos] >= '0' && bytes[iPos] <= '9')
		{
			iValue += (bytes[iPos] - 48) * iBase;
			iBase = (iBase * 16);
		}
		else if (bytes[iPos] >= 'A' && bytes[iPos] <= 'F')
		{
			iValue += (bytes[iPos] - 55) * iBase;
			iBase = (iBase * 16);
		}
	}

	return iValue;
}

int iGetMaxAmmo(int survivor, int type, int weapon, bool reserve, bool reset = false)
{
	bool bRewarded = bIsSurvivor(survivor) && (bIsDeveloper(survivor, 4) || bIsDeveloper(survivor, 6) || ((g_esPlayer[survivor].g_iRewardTypes & MT_REWARD_AMMO) && g_esPlayer[survivor].g_iAmmoBoost == 1));
	int iType = (type > 0 || weapon <= MaxClients) ? type : GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
	if (g_bSecondGame)
	{
		if (reserve)
		{
			switch (iType)
			{
				case MT_L4D2_AMMOTYPE_RIFLE: return (bRewarded && !reset) ? (g_esGeneral.g_cvMTAssaultRifleAmmo.IntValue * 2) : g_esGeneral.g_cvMTAssaultRifleAmmo.IntValue;
				case MT_L4D2_AMMOTYPE_SMG: return (bRewarded && !reset) ? iClamp(RoundToNearest(g_esGeneral.g_cvMTSMGAmmo.IntValue * 1.23), 1, 1000) : g_esGeneral.g_cvMTSMGAmmo.IntValue;
				case MT_L4D2_AMMOTYPE_SHOTGUN_TIER1: return (bRewarded && !reset) ? iClamp(RoundToNearest(g_esGeneral.g_cvMTShotgunAmmo.IntValue * 2.08), 1, 255) : g_esGeneral.g_cvMTShotgunAmmo.IntValue;
				case MT_L4D2_AMMOTYPE_SHOTGUN_TIER2: return (bRewarded && !reset) ? iClamp(RoundToNearest(g_esGeneral.g_cvMTAutoShotgunAmmo.IntValue * 2.22), 1, 255) : g_esGeneral.g_cvMTAutoShotgunAmmo.IntValue;
				case MT_L4D2_AMMOTYPE_HUNTING_RIFLE: return (bRewarded && !reset) ? (g_esGeneral.g_cvMTHuntingRifleAmmo.IntValue * 2) : g_esGeneral.g_cvMTHuntingRifleAmmo.IntValue;
				case MT_L4D2_AMMOTYPE_SNIPER_RIFLE: return (bRewarded && !reset) ? (g_esGeneral.g_cvMTSniperRifleAmmo.IntValue * 2) : g_esGeneral.g_cvMTSniperRifleAmmo.IntValue;
				case MT_L4D2_AMMOTYPE_GRENADE_LAUNCHER: return (bRewarded && !reset) ? (g_esGeneral.g_cvMTGrenadeLauncherAmmo.IntValue * 2) : g_esGeneral.g_cvMTGrenadeLauncherAmmo.IntValue;
			}
		}
		else
		{
			switch (iType)
			{
				case MT_L4D2_AMMOTYPE_PISTOL: return (bRewarded && !reset) ? 30 : 15;
				case MT_L4D2_AMMOTYPE_PISTOL_MAGNUM: return (bRewarded && !reset) ? 16 : 8;
				case MT_L4D2_AMMOTYPE_RIFLE: return (bRewarded && !reset) ? 100 : 50;
				case MT_L4D2_AMMOTYPE_SMG: return (bRewarded && !reset) ? 100 : 50;
				case MT_L4D2_AMMOTYPE_RIFLE_M60: return (bRewarded && !reset) ? 300 : 150;
				case MT_L4D2_AMMOTYPE_SHOTGUN_TIER1: return (bRewarded && !reset) ? 16 : 8;
				case MT_L4D2_AMMOTYPE_SHOTGUN_TIER2: return (bRewarded && !reset) ? 20 : 10;
				case MT_L4D2_AMMOTYPE_HUNTING_RIFLE: return (bRewarded && !reset) ? 30 : 15;
				case MT_L4D2_AMMOTYPE_SNIPER_RIFLE: return (bRewarded && !reset) ? 60 : 30;
				case MT_L4D2_AMMOTYPE_GRENADE_LAUNCHER: return (bRewarded && !reset) ? 2 : 1;
			}
		}
	}
	else
	{
		if (reserve)
		{
			switch (iType)
			{
				case MT_L4D1_AMMOTYPE_HUNTING_RIFLE: return (bRewarded && !reset) ? (g_esGeneral.g_cvMTHuntingRifleAmmo.IntValue * 2) : g_esGeneral.g_cvMTHuntingRifleAmmo.IntValue;
				case MT_L4D1_AMMOTYPE_RIFLE: return (bRewarded && !reset) ? (g_esGeneral.g_cvMTAssaultRifleAmmo.IntValue * 2) : g_esGeneral.g_cvMTAssaultRifleAmmo.IntValue;
				case MT_L4D1_AMMOTYPE_SMG: return (bRewarded && !reset) ? iClamp(RoundToNearest(g_esGeneral.g_cvMTSMGAmmo.IntValue * 1.23), 1, 1000) : g_esGeneral.g_cvMTSMGAmmo.IntValue;
				case MT_L4D1_AMMOTYPE_SHOTGUN: return (bRewarded && !reset) ? iClamp(RoundToNearest(g_esGeneral.g_cvMTShotgunAmmo.IntValue * 1.56), 1, 255) : g_esGeneral.g_cvMTShotgunAmmo.IntValue;
			}
		}
		else
		{
			switch (iType)
			{
				case MT_L4D1_AMMOTYPE_PISTOL: return (bRewarded && !reset) ? 30 : 15;
				case MT_L4D1_AMMOTYPE_HUNTING_RIFLE: return (bRewarded && !reset) ? 30 : 15;
				case MT_L4D1_AMMOTYPE_RIFLE: return (bRewarded && !reset) ? 100 : 50;
				case MT_L4D1_AMMOTYPE_SMG: return (bRewarded && !reset) ? 100 : 50;
				case MT_L4D1_AMMOTYPE_SHOTGUN: return (bRewarded && !reset) ? 20 : 10;
			}
		}
	}

	return 0;
}

int iGetMaxWeaponSkins(int developer)
{
	int iActiveWeapon = GetEntPropEnt(developer, Prop_Send, "m_hActiveWeapon");
	if (bIsValidEntity(iActiveWeapon))
	{
		char sClassname[32];
		GetEntityClassname(iActiveWeapon, sClassname, sizeof sClassname);
		if (StrEqual(sClassname[7], "pistol_magnum") || StrEqual(sClassname[7], "rifle") || StrEqual(sClassname[7], "rifle_ak47"))
		{
			return 2;
		}
		else if (StrEqual(sClassname[7], "smg") || StrEqual(sClassname[7], "smg_silenced")
			|| StrEqual(sClassname[7], "pumpshotgun") || StrEqual(sClassname[7], "shotgun_chrome")
			|| StrEqual(sClassname[7], "autoshotgun") || StrEqual(sClassname[7], "hunting_rifle"))
		{
			return 1;
		}
		else if (StrEqual(sClassname[7], "melee"))
		{
			char sWeapon[32];
			GetEntPropString(iActiveWeapon, Prop_Data, "m_strMapSetScriptName", sWeapon, sizeof sWeapon);
			if (StrEqual(sWeapon, "cricket_bat") || StrEqual(sWeapon, "crowbar"))
			{
				return 1;
			}
		}
	}

	return -1;
}

int iGetMessageType(int setting)
{
	int iMessageCount = 0, iMessages[10], iFlag = 0;
	for (int iBit = 0; iBit < (sizeof iMessages); iBit++)
	{
		iFlag = (1 << iBit);
		if (!(setting & iFlag))
		{
			continue;
		}

		iMessages[iMessageCount] = iFlag;
		iMessageCount++;
	}

	switch (iMessages[MT_GetRandomInt(0, (iMessageCount - 1))])
	{
		case 1: return 1;
		case 2: return 2;
		case 4: return 3;
		case 8: return 4;
		case 16: return 5;
		case 32: return 6;
		case 64: return 7;
		case 128: return 8;
		case 256: return 9;
		case 512: return 10;
		default: return MT_GetRandomInt(1, (sizeof iMessages));
	}
}

int iGetRandomRecipient(int recipient, int tank, int priority, bool none)
{
	bool bCondition = false;
	float flPercentage = 0.0;
	int iRecipient = recipient, iRecipientCount = 0;
	int[] iRecipients = new int[MaxClients + 1];
	if (g_esCache[tank].g_iShareRewards[priority] == 1 || g_esCache[tank].g_iShareRewards[priority] == 3)
	{
		for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
		{
			bCondition = none ? (g_esPlayer[iSurvivor].g_iRewardTypes <= 0) : (g_esPlayer[iSurvivor].g_iRewardTypes > 0);
			flPercentage = ((float(g_esPlayer[iSurvivor].g_iTankDamage[tank]) / float(g_esPlayer[tank].g_iTankHealth)) * 100.0);
			if (bIsHumanSurvivor(iSurvivor) && bCondition && (1.0 <= flPercentage < g_esCache[tank].g_flRewardPercentage[priority]) && iSurvivor != recipient)
			{
				iRecipients[iRecipientCount] = iSurvivor;
				iRecipientCount++;
			}
		}
	}

	if (iRecipientCount > 0)
	{
		iRecipient = iRecipients[MT_GetRandomInt(0, (iRecipientCount - 1))];
	}

	if ((g_esCache[tank].g_iShareRewards[priority] == 2 || g_esCache[tank].g_iShareRewards[priority] == 3) && (iRecipientCount == 0 || iRecipient == recipient))
	{
		bool bBot = false;
		for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
		{
			bCondition = none ? (g_esPlayer[iSurvivor].g_iRewardTypes <= 0) : (g_esPlayer[iSurvivor].g_iRewardTypes > 0);
			flPercentage = ((float(g_esPlayer[iSurvivor].g_iTankDamage[tank]) / float(g_esPlayer[tank].g_iTankHealth)) * 100.0);
			if (bIsSurvivor(iSurvivor) && bCondition && (1.0 <= flPercentage < g_esCache[tank].g_flRewardPercentage[priority]) && iSurvivor != recipient)
			{
				bBot = (g_esCache[tank].g_iShareRewards[priority] == 2) ? !bIsValidClient(iSurvivor, MT_CHECK_FAKECLIENT) : true;
				if (bBot)
				{
					iRecipients[iRecipientCount] = iSurvivor;
					iRecipientCount++;
				}
			}
		}

		if (iRecipientCount > 0)
		{
			iRecipient = iRecipients[MT_GetRandomInt(0, (iRecipientCount - 1))];
		}
	}

	return iRecipient;
}

int iGetRealType(int type, int exclude = 0, int tank = 0, int min = -1, int max = -1)
{
	Action aResult = Plugin_Continue;
	int iType = type;

	Call_StartForward(g_esGeneral.g_gfTypeChosenForward);
	Call_PushCellRef(iType);
	Call_PushCell(tank);
	Call_Finish(aResult);

	switch (aResult)
	{
		case Plugin_Stop: return 0;
		case Plugin_Handled: return iChooseType(exclude, tank, min, max);
		case Plugin_Changed: return iType;
	}

	return type;
}

int iGetRefEHandle(Address entityHandle)
{
	if (!entityHandle)
	{
		return INVALID_EHANDLE_INDEX;
	}

	Address adRefHandle = SDKCall(g_esGeneral.g_hSDKGetRefEHandle, entityHandle);
	return LoadFromAddress(adRefHandle, NumberType_Int32);
}

int iGetTankCount(bool manual, bool include = false)
{
	switch (manual)
	{
		case true:
		{
			int iTankCount = 0;
			for (int iTank = 1; iTank <= MaxClients; iTank++)
			{
				if (bIsTank(iTank, MT_CHECK_INGAME|MT_CHECK_ALIVE))
				{
					if (!include && bIsCustomTank(iTank))
					{
						continue;
					}

					iTankCount++;
				}
			}

			return iTankCount;
		}
		case false: return g_esGeneral.g_iTankCount;
	}

	return 0;
}

int iGetTypeCount(int type = 0)
{
	bool bCheck = false;
	int iTypeCount = 0;
	for (int iTank = 1; iTank <= MaxClients; iTank++)
	{
		bCheck = (type > 0) ? (g_esPlayer[iTank].g_iTankType == type) : (g_esPlayer[iTank].g_iTankType > 0);
		if (bIsTank(iTank, MT_CHECK_INGAME|MT_CHECK_ALIVE) && !g_esPlayer[iTank].g_bArtificial && bCheck)
		{
			iTypeCount++;
		}
	}

	return iTypeCount;
}

int iGetUsefulRewards(int survivor, int tank, int types, int priority)
{
	int iType = 0;
	if (g_esCache[tank].g_iUsefulRewards[priority] > 0)
	{
		if (bIsSurvivor(survivor, MT_CHECK_ALIVE))
		{
			int iAmmo = -1, iWeapon = GetPlayerWeaponSlot(survivor, 0);
			if (iWeapon > MaxClients)
			{
				iAmmo = GetEntProp(survivor, Prop_Send, "m_iAmmo", .element = iGetWeaponOffset(iWeapon));
			}

			if ((g_esCache[tank].g_iUsefulRewards[priority] & MT_USEFUL_REFILL) && !(types & MT_REWARD_REFILL) && ((g_esPlayer[survivor].g_bLastLife && g_esPlayer[survivor].g_iReviveCount > 0) || bIsSurvivorDisabled(survivor)) && -1 < iAmmo <= 10)
			{
				iType |= MT_REWARD_REFILL;
			}
			else if ((g_esCache[tank].g_iUsefulRewards[priority] & MT_USEFUL_HEALTH) && !(types & MT_REWARD_REFILL) && !(types & MT_REWARD_HEALTH) && ((g_esPlayer[survivor].g_bLastLife && g_esPlayer[survivor].g_iReviveCount > 0) || bIsSurvivorDisabled(survivor)))
			{
				iType |= MT_REWARD_HEALTH;
			}
			else if ((g_esCache[tank].g_iUsefulRewards[priority] & MT_USEFUL_AMMO) && !(types & MT_REWARD_REFILL) && !(types & MT_REWARD_AMMO) && -1 < iAmmo <= 10)
			{
				iType |= MT_REWARD_AMMO;
			}
		}
		else if ((g_esCache[tank].g_iUsefulRewards[priority] & MT_USEFUL_RESPAWN) && !(types & MT_REWARD_RESPAWN))
		{
			iType |= MT_REWARD_RESPAWN;
		}
	}

	return iType;
}

int iGetWeaponInfoID(int weapon)
{
	if (bIsValidEntity(weapon) && g_esGeneral.g_hSDKGetWeaponID != null)
	{
		int iWeaponID = SDKCall(g_esGeneral.g_hSDKGetWeaponID, weapon);
		if (iWeaponID != -1 && g_esGeneral.g_hSDKGetWeaponInfo != null)
		{
			return SDKCall(g_esGeneral.g_hSDKGetWeaponInfo, iWeaponID);
		}
	}

	return -1;
}

/**
 * ArrayList functions
 **/

void vClearAbilityList()
{
	for (int iPos = 0; iPos < (sizeof esGeneral::g_alAbilitySections); iPos++)
	{
		if (g_esGeneral.g_alAbilitySections[iPos] != null)
		{
			g_esGeneral.g_alAbilitySections[iPos].Clear();

			delete g_esGeneral.g_alAbilitySections[iPos];
		}
	}
}

void vClearColorKeysList()
{
	for (int iPos = 0; iPos < (sizeof esGeneral::g_alColorKeys); iPos++)
	{
		if (g_esGeneral.g_alColorKeys[iPos] != null)
		{
			g_esGeneral.g_alColorKeys[iPos].Clear();

			delete g_esGeneral.g_alColorKeys[iPos];
		}
	}
}

void vClearCompTypesList()
{
	if (g_esGeneral.g_alCompTypes != null)
	{
		g_esGeneral.g_alCompTypes.Clear();

		delete g_esGeneral.g_alCompTypes;
	}
}

void vClearPluginList()
{
	if (g_esGeneral.g_alPlugins != null)
	{
		g_esGeneral.g_alPlugins.Clear();

		delete g_esGeneral.g_alPlugins;
	}
}

void vClearSectionList()
{
	if (g_esGeneral.g_alSections != null)
	{
		g_esGeneral.g_alSections.Clear();

		delete g_esGeneral.g_alSections;
	}
}

/**
 * Timer functions & callbacks
 **/

void vResetTimers(bool delay = false)
{
	switch (delay)
	{
		case true: CreateTimer(g_esGeneral.g_flRegularDelay, tTimerDelayRegularWaves, .flags = TIMER_FLAG_NO_MAPCHANGE);
		case false:
		{
			if (g_esGeneral.g_hSDKHasAnySurvivorLeftSafeArea != null && g_esGeneral.g_adDirector != Address_Null && SDKCall(g_esGeneral.g_hSDKHasAnySurvivorLeftSafeArea, g_esGeneral.g_adDirector))
			{
				delete g_esGeneral.g_hRegularWavesTimer;

				g_esGeneral.g_hRegularWavesTimer = CreateTimer(g_esGeneral.g_flRegularInterval, tTimerRegularWaves, .flags = TIMER_REPEAT);
			}
		}
	}

	for (int iTank = 1; iTank <= MaxClients; iTank++)
	{
		if (bIsTankSupported(iTank))
		{
			vResetTimersForward(1, iTank);
		}
	}

	vResetTimersForward();
}

Action tTimerAnnounce(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!bIsTank(iTank))
	{
		return Plugin_Stop;
	}

	if (bIsTankSupported(iTank) && !bIsTankIdle(iTank))
	{
		char sOldName[33], sNewName[33];
		pack.ReadString(sOldName, sizeof sOldName);
		pack.ReadString(sNewName, sizeof sNewName);

		int iMode = pack.ReadCell();
		vChooseArrivalType(iTank, sOldName, sNewName, iMode);

		return Plugin_Stop;
	}

	return Plugin_Continue;
}

Action tTimerAnnounce2(Handle timer, int userid)
{
	int iTank = GetClientOfUserId(userid);
	if (!bIsTank(iTank))
	{
		return Plugin_Stop;
	}

	if (!bIsTankIdle(iTank))
	{
		vAnnounceTankArrival(iTank, "NoName");

		return Plugin_Stop;
	}

	return Plugin_Continue;
}

Action tTimerBloodEffect(Handle timer, int userid)
{
	int iTank = GetClientOfUserId(userid);
	if (!g_esGeneral.g_bPluginEnabled || !bIsTankSupported(iTank) || !bHasCoreAdminAccess(iTank) || g_esCache[iTank].g_iTankEnabled <= 0 || !(g_esCache[iTank].g_iBodyEffects & MT_PARTICLE_BLOOD) || !g_esPlayer[iTank].g_bBlood)
	{
		g_esPlayer[iTank].g_bBlood = false;

		return Plugin_Stop;
	}

	vAttachParticle(iTank, PARTICLE_BLOOD, 0.75, 30.0);

	return Plugin_Continue;
}

Action tTimerBlurEffect(Handle timer, int userid)
{
	int iTank = GetClientOfUserId(userid);
	if (!g_esGeneral.g_bPluginEnabled || !bIsTankSupported(iTank) || !bHasCoreAdminAccess(iTank) || g_esCache[iTank].g_iTankEnabled <= 0 || !(g_esCache[iTank].g_iPropsAttached & MT_PROP_BLUR) || !g_esPlayer[iTank].g_bBlur)
	{
		g_esPlayer[iTank].g_bBlur = false;

		return Plugin_Stop;
	}

	int iTankModel = EntRefToEntIndex(g_esPlayer[iTank].g_iBlur);
	if (iTankModel == INVALID_ENT_REFERENCE || !bIsValidEntity(iTankModel))
	{
		g_esPlayer[iTank].g_bBlur = false;
		g_esPlayer[iTank].g_iBlur = INVALID_ENT_REFERENCE;

		return Plugin_Stop;
	}

	float flTankPos[3], flTankAngles[3];
	GetClientAbsOrigin(iTank, flTankPos);
	GetClientAbsAngles(iTank, flTankAngles);
	if (bIsValidEntity(iTankModel))
	{
		TeleportEntity(iTankModel, flTankPos, flTankAngles);
		SetEntProp(iTankModel, Prop_Send, "m_nSequence", GetEntProp(iTank, Prop_Send, "m_nSequence"));
	}

	return Plugin_Continue;
}

Action tTimerCheckTankView(Handle timer, int userid)
{
	int iTank = GetClientOfUserId(userid);
	if (!g_esGeneral.g_bPluginEnabled || !bIsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT))
	{
		return Plugin_Stop;
	}

	QueryClientConVar(iTank, "z_view_distance", vViewDistanceQuery);

	return Plugin_Continue;
}

Action tTimerControlTank(Handle timer, int userid)
{
	int iTank = GetClientOfUserId(userid);
	if (!bIsTank(iTank))
	{
		return Plugin_Stop;
	}

	vTankSpawn(iTank, -1);

	return Plugin_Continue;
}

Action tTimerDelayRegularWaves(Handle timer)
{
	delete g_esGeneral.g_hRegularWavesTimer;

	g_esGeneral.g_hRegularWavesTimer = CreateTimer(g_esGeneral.g_flRegularInterval, tTimerRegularWaves, .flags = TIMER_REPEAT);

	return Plugin_Continue;
}

Action tTimerDelaySurvival(Handle timer)
{
	g_esGeneral.g_hSurvivalTimer = null;
	g_esGeneral.g_iSurvivalBlock = 2;

	return Plugin_Continue;
}

Action tTimerDevParticle(Handle timer, int userid)
{
	int iSurvivor = GetClientOfUserId(userid);
	if (!g_esGeneral.g_bPluginEnabled || !bIsSurvivor(iSurvivor) || !bIsDeveloper(iSurvivor, 0) || !g_esDeveloper[iSurvivor].g_bDevVisual || g_esDeveloper[iSurvivor].g_iDevParticle == 0 || g_esGeneral.g_bFinaleEnded)
	{
		g_esDeveloper[iSurvivor].g_bDevVisual = false;

		return Plugin_Stop;
	}

	vSetSurvivorEffects(iSurvivor, g_esDeveloper[iSurvivor].g_iDevParticle);

	return Plugin_Continue;
}

Action tTimerElectricEffect(Handle timer, int userid)
{
	int iTank = GetClientOfUserId(userid);
	if (!g_esGeneral.g_bPluginEnabled || !bIsTankSupported(iTank) || !bHasCoreAdminAccess(iTank) || g_esCache[iTank].g_iTankEnabled <= 0 || !(g_esCache[iTank].g_iBodyEffects & MT_PARTICLE_ELECTRICITY) || !g_esPlayer[iTank].g_bElectric)
	{
		g_esPlayer[iTank].g_bElectric = false;

		return Plugin_Stop;
	}

	switch (bIsValidClient(iTank, MT_CHECK_FAKECLIENT))
	{
		case true: vAttachParticle(iTank, PARTICLE_ELECTRICITY, 0.75, 30.0);
		case false:
		{
			for (int iCount = 1; iCount < 4; iCount++)
			{
				vAttachParticle(iTank, PARTICLE_ELECTRICITY, 0.75, (1.0 * float(iCount * 15)));
			}
		}
	}

	return Plugin_Continue;
}

Action tTimerExecuteCustomConfig(Handle timer, DataPack pack)
{
	pack.Reset();

	char sSavePath[PLATFORM_MAX_PATH];
	pack.ReadString(sSavePath, sizeof sSavePath);
	if (sSavePath[0] != '\0')
	{
		vLogMessage(MT_LOG_SERVER, _, "%s %T", MT_TAG, "ReloadingConfig", LANG_SERVER, sSavePath);
		vLoadConfigs(sSavePath, 2);
		vPluginStatus();
		vResetTimers();
		vToggleLogging();
	}

	return Plugin_Continue;
}

Action tTimerFireEffect(Handle timer, int userid)
{
	int iTank = GetClientOfUserId(userid);
	if (!g_esGeneral.g_bPluginEnabled || !bIsTankSupported(iTank) || !bHasCoreAdminAccess(iTank) || g_esCache[iTank].g_iTankEnabled <= 0 || !(g_esCache[iTank].g_iBodyEffects & MT_PARTICLE_FIRE) || !g_esPlayer[iTank].g_bFire)
	{
		g_esPlayer[iTank].g_bFire = false;

		return Plugin_Stop;
	}

	vAttachParticle(iTank, PARTICLE_FIRE, 0.75);

	return Plugin_Continue;
}

Action tTimerForceSpawnTank(Handle timer, int userid)
{
	int iTank = GetClientOfUserId(userid);
	if (!g_esGeneral.g_bPluginEnabled || !bIsTank(iTank) || !bIsInfectedGhost(iTank))
	{
		return Plugin_Stop;
	}

	int iAbility = -1;
	if (g_esGeneral.g_hSDKMaterializeFromGhost != null)
	{
		SDKCall(g_esGeneral.g_hSDKMaterializeFromGhost, iTank);
		iAbility = GetEntPropEnt(iTank, Prop_Send, "m_customAbility");
	}

	switch (iAbility)
	{
		case -1: MT_PrintToChat(iTank, "%s %t", MT_TAG3, "SpawnManually");
		default: vTankSpawn(iTank);
	}

	return Plugin_Continue;
}

Action tTimerHudPanel(Handle timer, int userid)
{
	int iPlayer = GetClientOfUserId(userid);
	if (!g_esGeneral.g_bPluginEnabled || !bIsValidClient(iPlayer) || !bIsDeveloper(iPlayer, .real = true) || iGetTankCount(true, true) <= 0)
	{
		g_esPlayer[iPlayer].g_hHudTimer = null;

		return Plugin_Stop;
	}

	vHudPanel(iPlayer, g_esPlayer[iPlayer].g_iHudPanelLevel);

	return Plugin_Continue;
}

Action tTimerIceEffect(Handle timer, int userid)
{
	int iTank = GetClientOfUserId(userid);
	if (!g_esGeneral.g_bPluginEnabled || !bIsTankSupported(iTank) || !bHasCoreAdminAccess(iTank) || g_esCache[iTank].g_iTankEnabled <= 0 || !(g_esCache[iTank].g_iBodyEffects & MT_PARTICLE_ICE) || !g_esPlayer[iTank].g_bIce)
	{
		g_esPlayer[iTank].g_bIce = false;

		return Plugin_Stop;
	}

	vAttachParticle(iTank, PARTICLE_ICE, 2.0, 30.0);

	return Plugin_Continue;
}

Action tTimerKillIdleTank(Handle timer, int userid)
{
	int iTank = GetClientOfUserId(userid);
	if (!g_esGeneral.g_bPluginEnabled || !bIsTank(iTank) || bIsTank(iTank, MT_CHECK_FAKECLIENT))
	{
		return Plugin_Stop;
	}

	if (bIsTankIdle(iTank, g_esGeneral.g_iIdleCheckMode))
	{
		ForcePlayerSuicide(iTank);

		return Plugin_Stop;
	}

	return Plugin_Continue;
}

Action tTimerKillStuckTank(Handle timer, int userid)
{
	int iTank = GetClientOfUserId(userid);
	if (!g_esGeneral.g_bPluginEnabled || !bIsTank(iTank) || !bIsPlayerIncapacitated(iTank))
	{
		return Plugin_Stop;
	}

	ForcePlayerSuicide(iTank);

	return Plugin_Continue;
}

Action tTimerLoopVoiceline(Handle timer, int userid)
{
	int iSurvivor = GetClientOfUserId(userid);
	if (!g_esGeneral.g_bPluginEnabled || !bIsSurvivor(iSurvivor) || g_esPlayer[iSurvivor].g_flVisualTime[2] == -1.0 || g_esPlayer[iSurvivor].g_flVisualTime[2] < GetGameTime() || g_esPlayer[iSurvivor].g_sLoopingVoiceline[0] == '\0' || g_esGeneral.g_bFinaleEnded)
	{
		g_esPlayer[iSurvivor].g_flVisualTime[2] = -1.0;
		g_esPlayer[iSurvivor].g_sLoopingVoiceline[0] = '\0';

		return Plugin_Stop;
	}

	if (!(g_esPlayer[iSurvivor].g_iRewardVisuals & MT_VISUAL_VOICELINE) || bHasIdlePlayer(iSurvivor) || bIsPlayerIdle(iSurvivor))
	{
		return Plugin_Continue;
	}

	vForceVocalize(iSurvivor, g_esPlayer[iSurvivor].g_sLoopingVoiceline);

	return Plugin_Continue;
}

Action tTimerMeteorEffect(Handle timer, int userid)
{
	int iTank = GetClientOfUserId(userid);
	if (!g_esGeneral.g_bPluginEnabled || !bIsTankSupported(iTank) || !bHasCoreAdminAccess(iTank) || g_esCache[iTank].g_iTankEnabled <= 0 || !(g_esCache[iTank].g_iBodyEffects & MT_PARTICLE_METEOR) || !g_esPlayer[iTank].g_bMeteor)
	{
		g_esPlayer[iTank].g_bMeteor = false;

		return Plugin_Stop;
	}

	vAttachParticle(iTank, PARTICLE_METEOR, 6.0, 30.0);

	return Plugin_Continue;
}

Action tTimerParticleVisual(Handle timer, int userid)
{
	int iSurvivor = GetClientOfUserId(userid);
	if (!g_esGeneral.g_bPluginEnabled || !bIsSurvivor(iSurvivor) || g_esPlayer[iSurvivor].g_flVisualTime[1] == -1.0 || g_esPlayer[iSurvivor].g_flVisualTime[1] < GetGameTime() || g_esPlayer[iSurvivor].g_iParticleEffect == 0 || g_esGeneral.g_bFinaleEnded)
	{
		g_esPlayer[iSurvivor].g_flVisualTime[1] = -1.0;
		g_esPlayer[iSurvivor].g_iParticleEffect = 0;

		return Plugin_Stop;
	}

	if ((bIsDeveloper(iSurvivor, 0) && g_esDeveloper[iSurvivor].g_bDevVisual && g_esDeveloper[iSurvivor].g_iDevParticle > 0) || !(g_esPlayer[iSurvivor].g_iRewardVisuals & MT_VISUAL_PARTICLE) || bHasIdlePlayer(iSurvivor) || bIsPlayerIdle(iSurvivor))
	{
		return Plugin_Continue;
	}

	vSetSurvivorEffects(iSurvivor, g_esPlayer[iSurvivor].g_iParticleEffect);

	return Plugin_Continue;
}

Action tTimerRefreshRewards(Handle timer)
{
	for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
	{
		if (bIsSurvivor(iSurvivor, MT_CHECK_INGAME|MT_CHECK_ALIVE))
		{
			vEndRewards(iSurvivor, false);
		}
	}

	return Plugin_Continue;
}

Action tTimerRegenerateAmmo(Handle timer)
{
	if (!g_esGeneral.g_bPluginEnabled)
	{
		return Plugin_Continue;
	}

	bool bDeveloper = false;
	char sWeapon[32];
	int iAmmo = 0, iAmmoOffset = 0, iMaxAmmo = 0, iClip = 0, iRegen = 0, iSlot = 0, iSpecialAmmo = 0, iUpgrades = 0;
	for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
	{
		if (!bIsSurvivor(iSurvivor))
		{
			continue;
		}

		bDeveloper = (bIsDeveloper(iSurvivor, 4) || bIsDeveloper(iSurvivor, 6));
		iRegen = (bDeveloper && g_esDeveloper[iSurvivor].g_iDevAmmoRegen > g_esPlayer[iSurvivor].g_iAmmoRegen) ? g_esDeveloper[iSurvivor].g_iDevAmmoRegen : g_esPlayer[iSurvivor].g_iAmmoRegen;
		if ((!bDeveloper && (!(g_esPlayer[iSurvivor].g_iRewardTypes & MT_REWARD_AMMO) || g_esPlayer[iSurvivor].g_flRewardTime[4] == -1.0)) || iRegen == 0)
		{
			continue;
		}

		iSlot = GetPlayerWeaponSlot(iSurvivor, 0);
		if (!bIsValidEntity(iSlot))
		{
			g_esPlayer[iSurvivor].g_iMaxClip[0] = 0;

			continue;
		}

		iClip = GetEntProp(iSlot, Prop_Send, "m_iClip1");
		if (iClip < g_esPlayer[iSurvivor].g_iMaxClip[0] && !GetEntProp(iSlot, Prop_Send, "m_bInReload"))
		{
			SetEntProp(iSlot, Prop_Send, "m_iClip1", (iClip + iRegen));
		}

		if ((iClip + iRegen) > g_esPlayer[iSurvivor].g_iMaxClip[0])
		{
			SetEntProp(iSlot, Prop_Send, "m_iClip1", g_esPlayer[iSurvivor].g_iMaxClip[0]);
		}

		if (g_bSecondGame)
		{
			iUpgrades = GetEntProp(iSlot, Prop_Send, "m_upgradeBitVec");
			if ((iUpgrades & MT_UPGRADE_INCENDIARY) || (iUpgrades & MT_UPGRADE_EXPLOSIVE))
			{
				iSpecialAmmo = GetEntProp(iSlot, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded");
				if (iSpecialAmmo < g_esPlayer[iSurvivor].g_iMaxClip[0])
				{
					SetEntProp(iSlot, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded", (iSpecialAmmo + iRegen));
				}

				if ((iSpecialAmmo + iRegen) > g_esPlayer[iSurvivor].g_iMaxClip[0])
				{
					SetEntProp(iSlot, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded", g_esPlayer[iSurvivor].g_iMaxClip[0]);
				}
			}
		}

		iAmmoOffset = iGetWeaponOffset(iSlot), iAmmo = GetEntProp(iSurvivor, Prop_Send, "m_iAmmo", .element = iAmmoOffset), iMaxAmmo = iGetMaxAmmo(iSurvivor, 0, iSlot, true);
		if (iAmmo < iMaxAmmo)
		{
			SetEntProp(iSurvivor, Prop_Send, "m_iAmmo", (iAmmo + iRegen), .element = iAmmoOffset);
		}

		if ((iAmmo + iRegen) > iMaxAmmo)
		{
			SetEntProp(iSurvivor, Prop_Send, "m_iAmmo", iMaxAmmo, .element = iAmmoOffset);
		}

		iSlot = GetPlayerWeaponSlot(iSurvivor, 1);
		if (!bIsValidEntity(iSlot))
		{
			g_esPlayer[iSurvivor].g_iMaxClip[1] = 0;

			continue;
		}

		GetEntityClassname(iSlot, sWeapon, sizeof sWeapon);
		if (!strncmp(sWeapon[7], "pistol", 6) || StrEqual(sWeapon[7], "chainsaw"))
		{
			iClip = GetEntProp(iSlot, Prop_Send, "m_iClip1");
			if (iClip < g_esPlayer[iSurvivor].g_iMaxClip[1])
			{
				SetEntProp(iSlot, Prop_Send, "m_iClip1", (iClip + iRegen));
			}

			if ((iClip + iRegen) > g_esPlayer[iSurvivor].g_iMaxClip[1])
			{
				SetEntProp(iSlot, Prop_Send, "m_iClip1", g_esPlayer[iSurvivor].g_iMaxClip[1]);
			}
		}
	}

	return Plugin_Continue;
}

Action tTimerRegenerateHealth(Handle timer)
{
	if (!g_esGeneral.g_bPluginEnabled)
	{
		return Plugin_Continue;
	}

	for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
	{
		vLifeLeech(iSurvivor, .type = 7);
	}

	return Plugin_Continue;
}

Action tTimerRegularWaves(Handle timer)
{
	int iCount = iGetTankCount(true);
	iCount = (iCount > 0) ? iCount : iGetTankCount(false);
	if (!bCanTypeSpawn() || g_esGeneral.g_bFinalMap || g_esGeneral.g_iTankWave > 0 || iCount > 0 || (g_esGeneral.g_iRegularLimit > 0 && g_esGeneral.g_iRegularCount >= g_esGeneral.g_iRegularLimit))
	{
		g_esGeneral.g_hRegularWavesTimer = null;

		return Plugin_Stop;
	}

	if (!g_esGeneral.g_bPluginEnabled || g_esGeneral.g_iRegularLimit == 0 || g_esGeneral.g_iRegularMode == 0 || g_esGeneral.g_iRegularWave == 0 || (g_esGeneral.g_iRegularAmount > 0 && iCount >= g_esGeneral.g_iRegularAmount))
	{
		return Plugin_Continue;
	}

	switch (g_esGeneral.g_iRegularAmount)
	{
		case 0: vRegularSpawn();
		default:
		{
			for (int iAmount = iCount; iAmount < g_esGeneral.g_iRegularAmount; iAmount++)
			{
				vRegularSpawn();
			}

			g_esGeneral.g_iRegularCount++;
		}
	}

	g_esGeneral.g_hRegularWavesTimer = null;

	return Plugin_Stop;
}

Action tTimerReloadConfigs(Handle timer)
{
	vCheckConfig(false);

	return Plugin_Continue;
}

Action tTimerRemoveTimescale(Handle timer, int ref)
{
	int iTimescale = EntRefToEntIndex(ref);
	if (iTimescale == INVALID_ENT_REFERENCE || !bIsValidEntity(iTimescale))
	{
		return Plugin_Stop;
	}

	AcceptEntityInput(iTimescale, "Stop");
	RemoveEntity(iTimescale);

	return Plugin_Continue;
}

Action tTimerResetType(Handle timer, int userid)
{
	int iTank = GetClientOfUserId(userid);
	if (!bIsValidClient(iTank))
	{
		vResetTank2(iTank);

		return Plugin_Stop;
	}

	vResetTank2(iTank);
	vCacheSettings(iTank);

	return Plugin_Continue;
}

Action tTimerRockEffects(Handle timer, DataPack pack)
{
	pack.Reset();

	int iRock = EntRefToEntIndex(pack.ReadCell()), iTank = GetClientOfUserId(pack.ReadCell());
	if (!g_esGeneral.g_bPluginEnabled || iRock == INVALID_ENT_REFERENCE || !bIsValidEntity(iRock) || !bIsTankSupported(iTank) || !bHasCoreAdminAccess(iTank) || g_esCache[iTank].g_iTankEnabled <= 0 || g_esCache[iTank].g_iRockEffects == 0)
	{
		return Plugin_Stop;
	}

	char sClassname[32];
	GetEntityClassname(iRock, sClassname, sizeof sClassname);
	if (!StrEqual(sClassname, "tank_rock"))
	{
		return Plugin_Stop;
	}

	if (g_esCache[iTank].g_iRockEffects & MT_ROCK_BLOOD)
	{
		vAttachParticle(iRock, PARTICLE_BLOOD, 0.75);
	}

	if (g_esCache[iTank].g_iRockEffects & MT_ROCK_ELECTRICITY)
	{
		vAttachParticle(iRock, PARTICLE_ELECTRICITY, 0.75);
	}

	if (g_esCache[iTank].g_iRockEffects & MT_ROCK_FIRE)
	{
		IgniteEntity(iRock, 120.0);
	}

	if (g_bSecondGame && (g_esCache[iTank].g_iRockEffects & MT_ROCK_SPIT))
	{
		EmitSoundToAll(SOUND_SPIT, iTank);
		vAttachParticle(iRock, PARTICLE_SPIT, 0.75);
	}

	return Plugin_Continue;
}

Action tTimerScreenEffect(Handle timer, int userid)
{
	int iSurvivor = GetClientOfUserId(userid);
	if (!g_esGeneral.g_bPluginEnabled || !bIsSurvivor(iSurvivor) || g_esPlayer[iSurvivor].g_flVisualTime[0] == -1.0 || g_esPlayer[iSurvivor].g_flVisualTime[0] < GetGameTime() || g_esGeneral.g_bFinaleEnded)
	{
		g_esPlayer[iSurvivor].g_flVisualTime[0] = -1.0;
		g_esPlayer[iSurvivor].g_iScreenColorVisual[0] = -1;
		g_esPlayer[iSurvivor].g_iScreenColorVisual[1] = -1;
		g_esPlayer[iSurvivor].g_iScreenColorVisual[2] = -1;
		g_esPlayer[iSurvivor].g_iScreenColorVisual[3] = -1;

		return Plugin_Stop;
	}

	if (!(g_esPlayer[iSurvivor].g_iRewardVisuals & MT_VISUAL_SCREEN) || bHasIdlePlayer(iSurvivor) || bIsPlayerIdle(iSurvivor) || bIsSurvivorHanging(iSurvivor) || bIsPlayerInThirdPerson(iSurvivor))
	{
		return Plugin_Continue;
	}
#if defined _ThirdPersonShoulder_Detect_included
	if (g_esPlayer[iSurvivor].g_bThirdPerson2)
	{
		return Plugin_Continue;
	}
#endif
	vScreenEffect(iSurvivor, 0, MT_ATTACK_RANGE, MT_ATTACK_RANGE, g_esPlayer[iSurvivor].g_iScreenColorVisual[0], g_esPlayer[iSurvivor].g_iScreenColorVisual[1], g_esPlayer[iSurvivor].g_iScreenColorVisual[2], g_esPlayer[iSurvivor].g_iScreenColorVisual[3]);

	return Plugin_Continue;
}

Action tTimerSmokeEffect(Handle timer, int userid)
{
	int iTank = GetClientOfUserId(userid);
	if (!g_esGeneral.g_bPluginEnabled || !bIsTankSupported(iTank) || !bHasCoreAdminAccess(iTank) || g_esCache[iTank].g_iTankEnabled <= 0 || !(g_esCache[iTank].g_iBodyEffects & MT_PARTICLE_SMOKE) || !g_esPlayer[iTank].g_bSmoke)
	{
		g_esPlayer[iTank].g_bSmoke = false;

		return Plugin_Stop;
	}

	vAttachParticle(iTank, PARTICLE_SMOKE, 1.5);

	return Plugin_Continue;
}

Action tTimerSpitEffect(Handle timer, int userid)
{
	int iTank = GetClientOfUserId(userid);
	if (!g_esGeneral.g_bPluginEnabled || !bIsTankSupported(iTank) || !bHasCoreAdminAccess(iTank) || g_esCache[iTank].g_iTankEnabled <= 0 || !(g_esCache[iTank].g_iBodyEffects & MT_PARTICLE_SPIT) || !g_esPlayer[iTank].g_bSpit)
	{
		g_esPlayer[iTank].g_bSpit = false;

		return Plugin_Stop;
	}

	vAttachParticle(iTank, PARTICLE_SPIT, 2.0, 30.0);
	iCreateParticle(iTank, PARTICLE_SPIT2, NULL_VECTOR, NULL_VECTOR, 0.95, 2.0, "mouth");

	return Plugin_Continue;
}

Action tTimerTankCountCheck(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell()), iAmount = pack.ReadCell(), iCount = iGetTankCount(true), iCount2 = iGetTankCount(false);
	if (!bIsTank(iTank) || iAmount == 0 || iCount >= iAmount || iCount2 >= iAmount || (g_esGeneral.g_bNormalMap && g_esGeneral.g_iTankWave == 0 && g_esGeneral.g_iRegularMode == 1 && g_esGeneral.g_iRegularWave == 1))
	{
		return Plugin_Stop;
	}
	else if (iCount < iAmount && iCount2 < iAmount)
	{
		vRegularSpawn();
	}

	return Plugin_Continue;
}

Action tTimerTankUpdate(Handle timer, int userid)
{
	int iTank = GetClientOfUserId(userid);
	if (!g_esGeneral.g_bPluginEnabled || !bIsTankSupported(iTank) || !bIsCustomTankSupported(iTank) || bIsPlayerIncapacitated(iTank) || g_esGeneral.g_bFinaleEnded)
	{
		return Plugin_Stop;
	}

	if (bIsTankIdle(iTank))
	{
		return Plugin_Continue;
	}

	switch (g_esCache[iTank].g_iSpawnType)
	{
		case 1:
		{
			if (!g_esPlayer[iTank].g_bBoss)
			{
				vSpawnModes(iTank, true);

				DataPack dpBoss;
				CreateDataTimer(0.1, tTimerUpdateBoss, dpBoss, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
				dpBoss.WriteCell(GetClientUserId(iTank));
				dpBoss.WriteCell(g_esCache[iTank].g_iBossStages);

				for (int iPos = 0; iPos < (sizeof esCache::g_iBossHealth); iPos++)
				{
					dpBoss.WriteCell(g_esCache[iTank].g_iBossHealth[iPos]);
					dpBoss.WriteCell(g_esCache[iTank].g_iBossType[iPos]);
				}
			}
		}
		case 2:
		{
			if (!g_esPlayer[iTank].g_bRandomized)
			{
				vSpawnModes(iTank, true);

				DataPack dpRandom;
				CreateDataTimer(g_esCache[iTank].g_flRandomInterval, tTimerUpdateRandomize, dpRandom, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
				dpRandom.WriteCell(GetClientUserId(iTank));
				dpRandom.WriteFloat(GetEngineTime());
			}
		}
		case 3:
		{
			if (!g_esPlayer[iTank].g_bTransformed)
			{
				vSpawnModes(iTank, true);
				CreateTimer(g_esCache[iTank].g_flTransformDelay, tTimerTransform, GetClientUserId(iTank), TIMER_FLAG_NO_MAPCHANGE);

				DataPack dpUntransform;
				CreateDataTimer((g_esCache[iTank].g_flTransformDuration + g_esCache[iTank].g_flTransformDelay), tTimerUntransform, dpUntransform, TIMER_FLAG_NO_MAPCHANGE);
				dpUntransform.WriteCell(GetClientUserId(iTank));
				dpUntransform.WriteCell(g_esPlayer[iTank].g_iTankType);
			}
		}
		case 4: vSpawnModes(iTank, true);
	}

	Call_StartForward(g_esGeneral.g_gfAbilityActivatedForward);
	Call_PushCell(iTank);
	Call_Finish();

	vCombineAbilitiesForward(iTank, MT_COMBO_MAINRANGE);

	return Plugin_Continue;
}

Action tTimerTankWave(Handle timer)
{
	if (g_esGeneral.g_bNormalMap || iGetTankCount(true, true) > 0 || iGetTankCount(false, true) > 0 || !(0 < g_esGeneral.g_iTankWave < 10))
	{
		g_esGeneral.g_hTankWaveTimer = null;

		return Plugin_Stop;
	}

	g_esGeneral.g_hTankWaveTimer = null;
	g_esGeneral.g_iTankWave++;

	return Plugin_Continue;
}

Action tTimerTransform(Handle timer, int userid)
{
	int iTank = GetClientOfUserId(userid);
	if (!g_esGeneral.g_bPluginEnabled || !bIsTankSupported(iTank) || !bHasCoreAdminAccess(iTank) || g_esCache[iTank].g_iTankEnabled <= 0 || !bIsCustomTankSupported(iTank) || !g_esPlayer[iTank].g_bTransformed)
	{
		vSpawnModes(iTank, false);

		return Plugin_Stop;
	}

	if (bIsTankIdle(iTank))
	{
		return Plugin_Continue;
	}

	int iPos = MT_GetRandomInt(0, (sizeof esCache::g_iTransformType - 1));
	vSetTankColor(iTank, g_esCache[iTank].g_iTransformType[iPos]);
	vTankSpawn(iTank, 3);

	return Plugin_Continue;
}

Action tTimerUntransform(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!bIsTankSupported(iTank) || g_esCache[iTank].g_iTankEnabled <= 0)
	{
		vSpawnModes(iTank, false);

		return Plugin_Stop;
	}

	if (bIsTankIdle(iTank))
	{
		return Plugin_Continue;
	}

	int iTankType = pack.ReadCell();
	vSetTankColor(iTank, iTankType);
	vTankSpawn(iTank, 4);
	vSpawnModes(iTank, false);

	return Plugin_Continue;
}

Action tTimerUpdateBoss(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!g_esGeneral.g_bPluginEnabled || !bIsTankSupported(iTank) || !bIsCustomTankSupported(iTank) || !bHasCoreAdminAccess(iTank) || g_esCache[iTank].g_iTankEnabled <= 0 || !g_esPlayer[iTank].g_bBoss)
	{
		vSpawnModes(iTank, false);

		return Plugin_Stop;
	}

	if (bIsTankIdle(iTank))
	{
		return Plugin_Continue;
	}

	int iBossStageCount = g_esPlayer[iTank].g_iBossStageCount,
		iBossStages = pack.ReadCell(), iBossHealths[5], iTypes[5];
	iBossHealths[0] = pack.ReadCell(), iTypes[0] = pack.ReadCell(),
	iBossHealths[1] = pack.ReadCell(), iTypes[1] = pack.ReadCell(),
	iBossHealths[2] = pack.ReadCell(), iTypes[2] = pack.ReadCell(),
	iBossHealths[3] = pack.ReadCell(), iTypes[3] = pack.ReadCell(),
	iBossHealths[4] = -1, iTypes[4] = 0;
	vEvolveBoss(iTank, iBossHealths[iBossStageCount], iBossStages, iTypes[iBossStageCount], (iBossStageCount + 1));

	return Plugin_Continue;
}

Action tTimerUpdateRandomize(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell());
	float flTime = pack.ReadFloat();
	if (!g_esGeneral.g_bPluginEnabled || !bIsTankSupported(iTank) || !bHasCoreAdminAccess(iTank) || g_esCache[iTank].g_iTankEnabled <= 0 || !bIsCustomTankSupported(iTank) || !g_esPlayer[iTank].g_bRandomized || (flTime + g_esCache[iTank].g_flRandomDuration < GetEngineTime()))
	{
		vSpawnModes(iTank, false);

		return Plugin_Stop;
	}

	if (bIsTankIdle(iTank))
	{
		return Plugin_Continue;
	}

	int iType = iChooseTank(iTank, 2, .mutate = false);

	switch (iType)
	{
		case 0: return Plugin_Continue;
		default: vSetTankColor(iTank, iType);
	}

	vTankSpawn(iTank, 2);

	return Plugin_Continue;
}