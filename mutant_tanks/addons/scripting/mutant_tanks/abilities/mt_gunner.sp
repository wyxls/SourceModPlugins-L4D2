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

#define MT_GUNNER_COMPILE_METHOD 0 // 0: packaged, 1: standalone

#if !defined MT_ABILITIES_MAIN
	#if MT_GUNNER_COMPILE_METHOD == 1
		#include <sourcemod>
		#include <mutant_tanks>
	#else
		#error This file must be inside "scripting/mutant_tanks/abilities" while compiling "mt_abilities.sp" to include its content.
	#endif
public Plugin myinfo =
{
	name = "[MT] Gunner Ability",
	author = MT_AUTHOR,
	description = "The Mutant Tank is armed with guns.",
	version = MT_VERSION,
	url = MT_URL
};

bool g_bDedicated, g_bSecondGame;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	switch (GetEngineVersion())
	{
		case Engine_Left4Dead: g_bSecondGame = false;
		case Engine_Left4Dead2: g_bSecondGame = true;
		default:
		{
			strcopy(error, err_max, "\"[MT] Gunner Ability\" only supports Left 4 Dead 1 & 2.");

			return APLRes_SilentFailure;
		}
	}

	g_bDedicated = IsDedicatedServer();

	return APLRes_Success;
}
#else
	#if MT_GUNNER_COMPILE_METHOD == 1
		#error This file must be compiled as a standalone plugin.
	#endif
#endif

#define SPRITE_LASER "sprites/laser.vmt"
#define SPRITE_LASERBEAM "sprites/laserbeam.vmt"

#define MT_GUNNER_SECTION "gunnerability"
#define MT_GUNNER_SECTION2 "gunner ability"
#define MT_GUNNER_SECTION3 "gunner_ability"
#define MT_GUNNER_SECTION4 "gunner"

#define MT_GUNNER_HUMANS (1 << 0) // human-controlled survivors
#define MT_GUNNER_BOTS (1 << 1) // survivor bots
#define MT_GUNNER_INCAPPED (1 << 2) // incapped survivors
#define MT_GUNNER_COMMON (1 << 3) // common infected
#define MT_GUNNER_SPECIAL (1 << 4) // special infected

#define MT_MENU_GUNNER "Gunner Ability"

bool g_bWeaponDisrupt[18] =
{
	false,
	false,
	true,
	false,
	true,
	false,
	false,
	false,
	false,
	true,
	false,
	false,
	false,
	true,
	false,
	false,
	false,
	false
};

char g_sWeaponModels[][] =
{
	"weapon_pistol",
	"weapon_smg",
	"weapon_pumpshotgun",
	"weapon_rifle",
	"weapon_autoshotgun",
	"weapon_hunting_rifle",
	"weapon_pistol_magnum",
	"weapon_smg_silenced",
	"weapon_smg_mp5",
	"weapon_shotgun_chrome",
	"weapon_rifle_ak47",
	"weapon_rifle_sg552",
	"weapon_rifle_desert",
	"weapon_shotgun_spas",
	"weapon_sniper_military",
	"weapon_sniper_scout",
	"weapon_sniper_awp",
	"weapon_rifle_m60"
}, g_sWeaponSounds[][] =
{
	"weapons/pistol/gunfire/pistol_fire.wav",
	"weapons/SMG/gunfire/smg_fire_1.wav",
	"weapons/shotgun/gunfire/shotgun_fire_1.wav",
	"weapons/rifle/gunfire/rifle_fire_1.wav",
	"weapons/auto_shotgun/gunfire/auto_shotgun_fire_1.wav",
	"weapons/hunting_rifle/gunfire/hunting_rifle_fire_1.wav",
	"weapons/magnum/gunfire/magnum_shoot.wav",
	"weapons/smg_silenced/gunfire/smg_fire_1.wav",
	"weapons/mp5navy/gunfire/mp5-1.wav",
	"weapons/shotgun_chrome/gunfire/shotgun_fire_1.wav",
	"weapons/rifle_ak47/gunfire/rifle_fire_1.wav",
	"weapons/sg552/gunfire/sg552-1.wav",
	"weapons/rifle_desert/gunfire/rifle_fire_1.wav",
	"weapons/auto_shotgun_spas/gunfire/shotgun_fire_1.wav",
	"weapons/sniper_military/gunfire/sniper_military_fire_1.wav",
	"weapons/scout/gunfire/scout_fire-1.wav",
	"weapons/awp/gunfire/awp1.wav",
	"weapons/machinegun_m60/gunfire/machinegun_fire_1.wav",
	"weapons/ClipEmpty_Rifle.wav",
	"weapons/shotgun/gunother/shotgun_load_shell_2.wav",
	"weapons/shotgun/gunother/shotgun_pump_1.wav"
};

enum struct esGunnerPlayer
{
	bool g_bActivated;
	bool g_bRainbowColor;
	bool g_bReloadingDrone;

	float g_flCloseAreasOnly;
	float g_flDroneFireTime;
	float g_flDroneLifetime;
	float g_flDroneReloadTime;
	float g_flDroneScanTime;
	float g_flDroneWalkTime;
	float g_flEnemyOrigin[3];
	float g_flGunnerAccuracy;
	float g_flGunnerChance;
	float g_flGunnerDamage;
	float g_flGunnerDuration;
	float g_flGunnerInterval;
	float g_flGunnerLoadTime;
	float g_flGunnerRange;
	float g_flGunnerReactionTime;
	float g_flOpenAreasOnly;

	int g_iAccessFlags;
	int g_iAmmoCount;
	int g_iComboAbility;
	int g_iCommonEnemy;
	int g_iCooldown;
	int g_iDrone;
	int g_iDroneBullets;
	int g_iGunType;
	int g_iGunnerAbility;
	int g_iGunnerBullets;
	int g_iGunnerClipSize;
	int g_iGunnerCooldown;
	int g_iGunnerGlow;
	int g_iGunnerGunType;
	int g_iGunnerMessage;
	int g_iGunnerTargetType;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanMode;
	int g_iImmunityFlags;
	int g_iRequiresHumans;
	int g_iSpecialEnemy;
	int g_iSurvivorEnemy;
	int g_iTankType;
}

esGunnerPlayer g_esGunnerPlayer[MAXPLAYERS + 1];

enum struct esGunnerAbility
{
	float g_flCloseAreasOnly;
	float g_flGunnerAccuracy;
	float g_flGunnerChance;
	float g_flGunnerDamage;
	float g_flGunnerDuration;
	float g_flGunnerInterval;
	float g_flGunnerLoadTime;
	float g_flGunnerRange;
	float g_flGunnerReactionTime;
	float g_flOpenAreasOnly;

	int g_iAccessFlags;
	int g_iComboAbility;
	int g_iComboPosition;
	int g_iGunnerAbility;
	int g_iGunnerBullets;
	int g_iGunnerClipSize;
	int g_iGunnerCooldown;
	int g_iGunnerGlow;
	int g_iGunnerGunType;
	int g_iGunnerMessage;
	int g_iGunnerTargetType;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanMode;
	int g_iImmunityFlags;
	int g_iRequiresHumans;
}

esGunnerAbility g_esGunnerAbility[MT_MAXTYPES + 1];

enum struct esGunnerCache
{
	float g_flCloseAreasOnly;
	float g_flGunnerAccuracy;
	float g_flGunnerChance;
	float g_flGunnerDamage;
	float g_flGunnerDuration;
	float g_flGunnerInterval;
	float g_flGunnerLoadTime;
	float g_flGunnerRange;
	float g_flGunnerReactionTime;
	float g_flOpenAreasOnly;

	int g_iComboAbility;
	int g_iGunnerAbility;
	int g_iGunnerBullets;
	int g_iGunnerClipSize;
	int g_iGunnerCooldown;
	int g_iGunnerGlow;
	int g_iGunnerGunType;
	int g_iGunnerMessage;
	int g_iGunnerTargetType;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanMode;
	int g_iRequiresHumans;
}

esGunnerCache g_esGunnerCache[MAXPLAYERS + 1];

float g_flLastTime = 0.0;

int g_iGunnerSprite = -1;

#if !defined MT_ABILITIES_MAIN
public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");
	LoadTranslations("mutant_tanks_names.phrases");

	RegConsoleCmd("sm_mt_gunner", cmdGunnerInfo, "View information about the Gunner ability.");
}
#endif

#if defined MT_ABILITIES_MAIN
void vGunnerMapStart()
#else
public void OnMapStart()
#endif
{
	for (int iPos = 0; iPos < sizeof g_sWeaponSounds; iPos++)
	{
		if (!g_bSecondGame && 6 <= iPos <= sizeof g_sWeaponModels)
		{
			continue;
		}

		if (iPos < sizeof g_sWeaponModels)
		{
			PrecacheModel(g_sWeaponModels[iPos], true);
		}

		PrecacheSound(g_sWeaponSounds[iPos], true);
	}

	switch (g_bSecondGame)
	{
		case true: g_iGunnerSprite = PrecacheModel(SPRITE_LASERBEAM, true);
		case false: g_iGunnerSprite = PrecacheModel(SPRITE_LASER, true);
	}

	vGunnerReset();
}

#if defined MT_ABILITIES_MAIN
void vGunnerClientPutInServer(int client)
#else
public void OnClientPutInServer(int client)
#endif
{
	vRemoveGunner(client);
}

#if defined MT_ABILITIES_MAIN
void vGunnerClientDisconnect_Post(int client)
#else
public void OnClientDisconnect_Post(int client)
#endif
{
	vRemoveGunner(client);
}

#if defined MT_ABILITIES_MAIN
void vGunnerMapEnd()
#else
public void OnMapEnd()
#endif
{
	vGunnerReset();
}

#if defined MT_ABILITIES_MAIN
void vGunnerPluginEnd()
#else
public void MT_OnPluginEnd()
#endif
{
	for (int iTank = 1; iTank <= MaxClients; iTank++)
	{
		if (bIsTank(iTank, MT_CHECK_INGAME|MT_CHECK_ALIVE))
		{
			vRemoveGunner(iTank);
		}
	}
}

#if !defined MT_ABILITIES_MAIN
Action cmdGunnerInfo(int client, int args)
{
	client = iGetListenServerHost(client, g_bDedicated);

	if (!MT_IsCorePluginEnabled())
	{
		MT_ReplyToCommand(client, "%s %t", MT_TAG5, "PluginDisabled");

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
		case false: vGunnerMenu(client, MT_GUNNER_SECTION4, 0);
	}

	return Plugin_Handled;
}
#endif

void vGunnerMenu(int client, const char[] name, int item)
{
	if (StrContains(MT_GUNNER_SECTION4, name, false) == -1)
	{
		return;
	}

	Menu mAbilityMenu = new Menu(iGunnerMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Gunner Ability Information");
	mAbilityMenu.AddItem("Status", "Status");
	mAbilityMenu.AddItem("Ammunition", "Ammunition");
	mAbilityMenu.AddItem("Buttons", "Buttons");
	mAbilityMenu.AddItem("Button Mode", "Button Mode");
	mAbilityMenu.AddItem("Cooldown", "Cooldown");
	mAbilityMenu.AddItem("Details", "Details");
	mAbilityMenu.AddItem("Duration", "Duration");
	mAbilityMenu.AddItem("Human Support", "Human Support");
	mAbilityMenu.DisplayAt(client, item, MENU_TIME_FOREVER);
}

int iGunnerMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esGunnerCache[param1].g_iGunnerAbility == 0) ? "AbilityStatus1" : "AbilityStatus2");
				case 1: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityAmmo", (g_esGunnerCache[param1].g_iHumanAmmo - g_esGunnerPlayer[param1].g_iAmmoCount), g_esGunnerCache[param1].g_iHumanAmmo);
				case 2: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityButtons");
				case 3: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esGunnerCache[param1].g_iHumanMode == 0) ? "AbilityButtonMode1" : "AbilityButtonMode2");
				case 4: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityCooldown", ((g_esGunnerCache[param1].g_iHumanAbility == 1) ? g_esGunnerCache[param1].g_iHumanCooldown : g_esGunnerCache[param1].g_iGunnerCooldown));
				case 5: MT_PrintToChat(param1, "%s %t", MT_TAG3, "GunnerDetails");
				case 6: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityDuration", g_esGunnerCache[param1].g_flGunnerDuration);
				case 7: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esGunnerCache[param1].g_iHumanAbility == 0) ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME))
			{
				vGunnerMenu(param1, MT_GUNNER_SECTION4, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pGunner = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "GunnerMenu", param1);
			pGunner.SetTitle(sMenuTitle);
		}
		case MenuAction_DisplayItem:
		{
			if (param2 >= 0)
			{
				char sMenuOption[PLATFORM_MAX_PATH];

				switch (param2)
				{
					case 0: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "Status", param1);
					case 1: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "Ammunition", param1);
					case 2: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "Buttons", param1);
					case 3: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "ButtonMode", param1);
					case 4: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "Cooldown", param1);
					case 5: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "Details", param1);
					case 6: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "Duration", param1);
					case 7: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "HumanSupport", param1);
				}

				return RedrawMenuItem(sMenuOption);
			}
		}
	}

	return 0;
}

#if defined MT_ABILITIES_MAIN
void vGunnerDisplayMenu(Menu menu)
#else
public void MT_OnDisplayMenu(Menu menu)
#endif
{
	menu.AddItem(MT_MENU_GUNNER, MT_MENU_GUNNER);
}

#if defined MT_ABILITIES_MAIN
void vGunnerMenuItemSelected(int client, const char[] info)
#else
public void MT_OnMenuItemSelected(int client, const char[] info)
#endif
{
	if (StrEqual(info, MT_MENU_GUNNER, false))
	{
		vGunnerMenu(client, MT_GUNNER_SECTION4, 0);
	}
}

#if defined MT_ABILITIES_MAIN
void vGunnerMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#else
public void MT_OnMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#endif
{
	if (StrEqual(info, MT_MENU_GUNNER, false))
	{
		FormatEx(buffer, size, "%T", "GunnerMenu2", client);
	}
}

public void OnGameFrame()
{
	float flTime = GetEngineTime(), flDuration = (flTime - g_flLastTime);
	if (flDuration < 0.0 || flDuration > 1.0)
	{
		flDuration = 0.0;
	}

	for (int iTank = 1; iTank <= MaxClients; iTank++)
	{
		if (MT_IsTankSupported(iTank) && g_esGunnerPlayer[iTank].g_bActivated)
		{
			vGunner3(iTank, flTime, flDuration);
		}
	}

	g_flLastTime = flTime;
}

#if defined MT_ABILITIES_MAIN
void vGunnerPluginCheck(ArrayList list)
#else
public void MT_OnPluginCheck(ArrayList list)
#endif
{
	list.PushString(MT_MENU_GUNNER);
}

#if defined MT_ABILITIES_MAIN
void vGunnerAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#else
public void MT_OnAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#endif
{
	list.PushString(MT_GUNNER_SECTION);
	list2.PushString(MT_GUNNER_SECTION2);
	list3.PushString(MT_GUNNER_SECTION3);
	list4.PushString(MT_GUNNER_SECTION4);
}

#if defined MT_ABILITIES_MAIN
void vGunnerCombineAbilities(int tank, int type, const float random, const char[] combo)
#else
public void MT_OnCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
#endif
{
	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esGunnerCache[tank].g_iHumanAbility != 2)
	{
		g_esGunnerAbility[g_esGunnerPlayer[tank].g_iTankType].g_iComboPosition = -1;

		return;
	}

	g_esGunnerAbility[g_esGunnerPlayer[tank].g_iTankType].g_iComboPosition = -1;

	char sCombo[320], sSet[4][32];
	FormatEx(sCombo, sizeof sCombo, ",%s,", combo);
	FormatEx(sSet[0], sizeof sSet[], ",%s,", MT_GUNNER_SECTION);
	FormatEx(sSet[1], sizeof sSet[], ",%s,", MT_GUNNER_SECTION2);
	FormatEx(sSet[2], sizeof sSet[], ",%s,", MT_GUNNER_SECTION3);
	FormatEx(sSet[3], sizeof sSet[], ",%s,", MT_GUNNER_SECTION4);
	if (StrContains(sCombo, sSet[0], false) != -1 || StrContains(sCombo, sSet[1], false) != -1 || StrContains(sCombo, sSet[2], false) != -1 || StrContains(sCombo, sSet[3], false) != -1)
	{
		if (type == MT_COMBO_MAINRANGE && g_esGunnerCache[tank].g_iGunnerAbility == 1 && g_esGunnerCache[tank].g_iComboAbility == 1 && !g_esGunnerPlayer[tank].g_bActivated)
		{
			char sAbilities[320], sSubset[10][32];
			strcopy(sAbilities, sizeof sAbilities, combo);
			ExplodeString(sAbilities, ",", sSubset, sizeof sSubset, sizeof sSubset[]);

			float flDelay = 0.0;
			for (int iPos = 0; iPos < (sizeof sSubset); iPos++)
			{
				if (StrEqual(sSubset[iPos], MT_GUNNER_SECTION, false) || StrEqual(sSubset[iPos], MT_GUNNER_SECTION2, false) || StrEqual(sSubset[iPos], MT_GUNNER_SECTION3, false) || StrEqual(sSubset[iPos], MT_GUNNER_SECTION4, false))
				{
					g_esGunnerAbility[g_esGunnerPlayer[tank].g_iTankType].g_iComboPosition = iPos;

					if (random <= MT_GetCombinationSetting(tank, 1, iPos))
					{
						flDelay = MT_GetCombinationSetting(tank, 4, iPos);

						switch (flDelay)
						{
							case 0.0: vGunner(tank);
							default: CreateTimer(flDelay, tTimerGunnerCombo, GetClientUserId(tank), TIMER_FLAG_NO_MAPCHANGE);
						}
					}

					break;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vGunnerConfigsLoad(int mode)
#else
public void MT_OnConfigsLoad(int mode)
#endif
{
	switch (mode)
	{
		case 1:
		{
			int iMaxType = MT_GetMaxType();
			for (int iIndex = MT_GetMinType(); iIndex <= iMaxType; iIndex++)
			{
				g_esGunnerAbility[iIndex].g_iAccessFlags = 0;
				g_esGunnerAbility[iIndex].g_iImmunityFlags = 0;
				g_esGunnerAbility[iIndex].g_flCloseAreasOnly = 0.0;
				g_esGunnerAbility[iIndex].g_iComboAbility = 0;
				g_esGunnerAbility[iIndex].g_iComboPosition = -1;
				g_esGunnerAbility[iIndex].g_iHumanAbility = 0;
				g_esGunnerAbility[iIndex].g_iHumanAmmo = 5;
				g_esGunnerAbility[iIndex].g_iHumanCooldown = 0;
				g_esGunnerAbility[iIndex].g_iHumanMode = 1;
				g_esGunnerAbility[iIndex].g_flOpenAreasOnly = 0.0;
				g_esGunnerAbility[iIndex].g_iRequiresHumans = 0;
				g_esGunnerAbility[iIndex].g_iGunnerAbility = 0;
				g_esGunnerAbility[iIndex].g_iGunnerMessage = 0;
				g_esGunnerAbility[iIndex].g_flGunnerAccuracy = 2.0;
				g_esGunnerAbility[iIndex].g_iGunnerBullets = 3;
				g_esGunnerAbility[iIndex].g_flGunnerChance = 33.3;
				g_esGunnerAbility[iIndex].g_iGunnerClipSize = 30;
				g_esGunnerAbility[iIndex].g_iGunnerCooldown = 0;
				g_esGunnerAbility[iIndex].g_flGunnerDamage = 5.0;
				g_esGunnerAbility[iIndex].g_flGunnerDuration = 5.0;
				g_esGunnerAbility[iIndex].g_iGunnerGlow = 1;
				g_esGunnerAbility[iIndex].g_iGunnerGunType = 0;
				g_esGunnerAbility[iIndex].g_flGunnerInterval = 1.0;
				g_esGunnerAbility[iIndex].g_flGunnerLoadTime = 1.0;
				g_esGunnerAbility[iIndex].g_flGunnerRange = 500.0;
				g_esGunnerAbility[iIndex].g_flGunnerReactionTime = 1.0;
				g_esGunnerAbility[iIndex].g_iGunnerTargetType = 0;
			}
		}
		case 3:
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (bIsValidClient(iPlayer))
				{
					g_esGunnerPlayer[iPlayer].g_iAccessFlags = 0;
					g_esGunnerPlayer[iPlayer].g_iImmunityFlags = 0;
					g_esGunnerPlayer[iPlayer].g_flCloseAreasOnly = 0.0;
					g_esGunnerPlayer[iPlayer].g_iComboAbility = 0;
					g_esGunnerPlayer[iPlayer].g_iHumanAbility = 0;
					g_esGunnerPlayer[iPlayer].g_iHumanAmmo = 0;
					g_esGunnerPlayer[iPlayer].g_iHumanCooldown = 0;
					g_esGunnerPlayer[iPlayer].g_iHumanMode = 0;
					g_esGunnerPlayer[iPlayer].g_flOpenAreasOnly = 0.0;
					g_esGunnerPlayer[iPlayer].g_iRequiresHumans = 0;
					g_esGunnerPlayer[iPlayer].g_iGunnerAbility = 0;
					g_esGunnerPlayer[iPlayer].g_iGunnerMessage = 0;
					g_esGunnerPlayer[iPlayer].g_flGunnerAccuracy = 0.0;
					g_esGunnerPlayer[iPlayer].g_iGunnerBullets = 0;
					g_esGunnerPlayer[iPlayer].g_flGunnerChance = 0.0;
					g_esGunnerPlayer[iPlayer].g_iGunnerClipSize = 0;
					g_esGunnerPlayer[iPlayer].g_iGunnerCooldown = 0;
					g_esGunnerPlayer[iPlayer].g_flGunnerDamage = 0.0;
					g_esGunnerPlayer[iPlayer].g_flGunnerDuration = 0.0;
					g_esGunnerPlayer[iPlayer].g_iGunnerGlow = 0;
					g_esGunnerPlayer[iPlayer].g_iGunnerGunType = 0;
					g_esGunnerPlayer[iPlayer].g_flGunnerInterval = 0.0;
					g_esGunnerPlayer[iPlayer].g_flGunnerLoadTime = 0.0;
					g_esGunnerPlayer[iPlayer].g_flGunnerRange = 0.0;
					g_esGunnerPlayer[iPlayer].g_flGunnerReactionTime = 0.0;
					g_esGunnerPlayer[iPlayer].g_iGunnerTargetType = 0;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vGunnerConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#else
public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#endif
{
	if (mode == 3 && bIsValidClient(admin))
	{
		g_esGunnerPlayer[admin].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_GUNNER_SECTION, MT_GUNNER_SECTION2, MT_GUNNER_SECTION3, MT_GUNNER_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esGunnerPlayer[admin].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esGunnerPlayer[admin].g_iComboAbility = iGetKeyValue(subsection, MT_GUNNER_SECTION, MT_GUNNER_SECTION2, MT_GUNNER_SECTION3, MT_GUNNER_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esGunnerPlayer[admin].g_iComboAbility, value, 0, 1);
		g_esGunnerPlayer[admin].g_iHumanAbility = iGetKeyValue(subsection, MT_GUNNER_SECTION, MT_GUNNER_SECTION2, MT_GUNNER_SECTION3, MT_GUNNER_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esGunnerPlayer[admin].g_iHumanAbility, value, 0, 2);
		g_esGunnerPlayer[admin].g_iHumanAmmo = iGetKeyValue(subsection, MT_GUNNER_SECTION, MT_GUNNER_SECTION2, MT_GUNNER_SECTION3, MT_GUNNER_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esGunnerPlayer[admin].g_iHumanAmmo, value, 0, 99999);
		g_esGunnerPlayer[admin].g_iHumanCooldown = iGetKeyValue(subsection, MT_GUNNER_SECTION, MT_GUNNER_SECTION2, MT_GUNNER_SECTION3, MT_GUNNER_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esGunnerPlayer[admin].g_iHumanCooldown, value, 0, 99999);
		g_esGunnerPlayer[admin].g_iHumanMode = iGetKeyValue(subsection, MT_GUNNER_SECTION, MT_GUNNER_SECTION2, MT_GUNNER_SECTION3, MT_GUNNER_SECTION4, key, "HumanMode", "Human Mode", "Human_Mode", "hmode", g_esGunnerPlayer[admin].g_iHumanMode, value, 0, 1);
		g_esGunnerPlayer[admin].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_GUNNER_SECTION, MT_GUNNER_SECTION2, MT_GUNNER_SECTION3, MT_GUNNER_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esGunnerPlayer[admin].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esGunnerPlayer[admin].g_iRequiresHumans = iGetKeyValue(subsection, MT_GUNNER_SECTION, MT_GUNNER_SECTION2, MT_GUNNER_SECTION3, MT_GUNNER_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esGunnerPlayer[admin].g_iRequiresHumans, value, 0, 32);
		g_esGunnerPlayer[admin].g_iGunnerAbility = iGetKeyValue(subsection, MT_GUNNER_SECTION, MT_GUNNER_SECTION2, MT_GUNNER_SECTION3, MT_GUNNER_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esGunnerPlayer[admin].g_iGunnerAbility, value, 0, 1);
		g_esGunnerPlayer[admin].g_iGunnerMessage = iGetKeyValue(subsection, MT_GUNNER_SECTION, MT_GUNNER_SECTION2, MT_GUNNER_SECTION3, MT_GUNNER_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esGunnerPlayer[admin].g_iGunnerMessage, value, 0, 1);
		g_esGunnerPlayer[admin].g_flGunnerAccuracy = flGetKeyValue(subsection, MT_GUNNER_SECTION, MT_GUNNER_SECTION2, MT_GUNNER_SECTION3, MT_GUNNER_SECTION4, key, "GunnerAccuracy", "Gunner Accuracy", "Gunner_Accuracy", "accuracy", g_esGunnerPlayer[admin].g_flGunnerAccuracy, value, 0.1, 5.0);
		g_esGunnerPlayer[admin].g_iGunnerBullets = iGetKeyValue(subsection, MT_GUNNER_SECTION, MT_GUNNER_SECTION2, MT_GUNNER_SECTION3, MT_GUNNER_SECTION4, key, "GunnerBullets", "Gunner Bullets", "Gunner_Bullets", "bullets", g_esGunnerPlayer[admin].g_iGunnerBullets, value, 1, 99999);
		g_esGunnerPlayer[admin].g_flGunnerChance = flGetKeyValue(subsection, MT_GUNNER_SECTION, MT_GUNNER_SECTION2, MT_GUNNER_SECTION3, MT_GUNNER_SECTION4, key, "GunnerChance", "Gunner Chance", "Gunner_Chance", "chance", g_esGunnerPlayer[admin].g_flGunnerChance, value, 0.0, 100.0);
		g_esGunnerPlayer[admin].g_iGunnerClipSize = iGetKeyValue(subsection, MT_GUNNER_SECTION, MT_GUNNER_SECTION2, MT_GUNNER_SECTION3, MT_GUNNER_SECTION4, key, "GunnerClipSize", "Gunner Clip Size", "Gunner_Clip_Size", "clipsize", g_esGunnerPlayer[admin].g_iGunnerClipSize, value, 1, 99999);
		g_esGunnerPlayer[admin].g_iGunnerCooldown = iGetKeyValue(subsection, MT_GUNNER_SECTION, MT_GUNNER_SECTION2, MT_GUNNER_SECTION3, MT_GUNNER_SECTION4, key, "GunnerCooldown", "Gunner Cooldown", "Gunner_Cooldown", "cooldown", g_esGunnerPlayer[admin].g_iGunnerCooldown, value, 0, 99999);
		g_esGunnerPlayer[admin].g_flGunnerDamage = flGetKeyValue(subsection, MT_GUNNER_SECTION, MT_GUNNER_SECTION2, MT_GUNNER_SECTION3, MT_GUNNER_SECTION4, key, "GunnerDamage", "Gunner Damage", "Gunner_Damage", "damage", g_esGunnerPlayer[admin].g_flGunnerDamage, value, 0.0, 99999.0);
		g_esGunnerPlayer[admin].g_flGunnerDuration = flGetKeyValue(subsection, MT_GUNNER_SECTION, MT_GUNNER_SECTION2, MT_GUNNER_SECTION3, MT_GUNNER_SECTION4, key, "GunnerDuration", "Gunner Duration", "Gunner_Duration", "duration", g_esGunnerPlayer[admin].g_flGunnerDuration, value, 0.1, 99999.0);
		g_esGunnerPlayer[admin].g_iGunnerGlow = iGetKeyValue(subsection, MT_GUNNER_SECTION, MT_GUNNER_SECTION2, MT_GUNNER_SECTION3, MT_GUNNER_SECTION4, key, "GunnerGlow", "Gunner Glow", "Gunner_Glow", "glow", g_esGunnerPlayer[admin].g_iGunnerGlow, value, 0, 1);
		g_esGunnerPlayer[admin].g_iGunnerGunType = iGetKeyValue(subsection, MT_GUNNER_SECTION, MT_GUNNER_SECTION2, MT_GUNNER_SECTION3, MT_GUNNER_SECTION4, key, "GunnerGunType", "Gunner Gun Type", "Gunner_Gun_Type", "guntype", g_esGunnerPlayer[admin].g_iGunnerGunType, value, 0, (g_bSecondGame ? 18 : 6));
		g_esGunnerPlayer[admin].g_flGunnerInterval = flGetKeyValue(subsection, MT_GUNNER_SECTION, MT_GUNNER_SECTION2, MT_GUNNER_SECTION3, MT_GUNNER_SECTION4, key, "GunnerInterval", "Gunner Interval", "Gunner_Interval", "interval", g_esGunnerPlayer[admin].g_flGunnerInterval, value, 0.1, 99999.0);
		g_esGunnerPlayer[admin].g_flGunnerLoadTime = flGetKeyValue(subsection, MT_GUNNER_SECTION, MT_GUNNER_SECTION2, MT_GUNNER_SECTION3, MT_GUNNER_SECTION4, key, "GunnerLoadTime", "Gunner Load Time", "Gunner_Load_Time", "loadtime", g_esGunnerPlayer[admin].g_flGunnerLoadTime, value, 0.1, 99999.0);
		g_esGunnerPlayer[admin].g_flGunnerRange = flGetKeyValue(subsection, MT_GUNNER_SECTION, MT_GUNNER_SECTION2, MT_GUNNER_SECTION3, MT_GUNNER_SECTION4, key, "GunnerRange", "Gunner Range", "Gunner_Range", "range", g_esGunnerPlayer[admin].g_flGunnerRange, value, 1.0, 99999.0);
		g_esGunnerPlayer[admin].g_flGunnerReactionTime = flGetKeyValue(subsection, MT_GUNNER_SECTION, MT_GUNNER_SECTION2, MT_GUNNER_SECTION3, MT_GUNNER_SECTION4, key, "GunnerReactionTime", "Gunner Reaction Time", "Gunner_Reaction_Time", "reactiontime", g_esGunnerPlayer[admin].g_flGunnerReactionTime, value, 0.1, 99999.0);
		g_esGunnerPlayer[admin].g_iGunnerTargetType = iGetKeyValue(subsection, MT_GUNNER_SECTION, MT_GUNNER_SECTION2, MT_GUNNER_SECTION3, MT_GUNNER_SECTION4, key, "GunnerTargetType", "Gunner Target Type", "Gunner_Target_Type", "targettype", g_esGunnerPlayer[admin].g_iGunnerTargetType, value, 0, 31);
		g_esGunnerPlayer[admin].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_GUNNER_SECTION, MT_GUNNER_SECTION2, MT_GUNNER_SECTION3, MT_GUNNER_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esGunnerPlayer[admin].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_GUNNER_SECTION, MT_GUNNER_SECTION2, MT_GUNNER_SECTION3, MT_GUNNER_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}

	if (mode < 3 && type > 0)
	{
		g_esGunnerAbility[type].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_GUNNER_SECTION, MT_GUNNER_SECTION2, MT_GUNNER_SECTION3, MT_GUNNER_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esGunnerAbility[type].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esGunnerAbility[type].g_iComboAbility = iGetKeyValue(subsection, MT_GUNNER_SECTION, MT_GUNNER_SECTION2, MT_GUNNER_SECTION3, MT_GUNNER_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esGunnerAbility[type].g_iComboAbility, value, 0, 1);
		g_esGunnerAbility[type].g_iHumanAbility = iGetKeyValue(subsection, MT_GUNNER_SECTION, MT_GUNNER_SECTION2, MT_GUNNER_SECTION3, MT_GUNNER_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esGunnerAbility[type].g_iHumanAbility, value, 0, 2);
		g_esGunnerAbility[type].g_iHumanAmmo = iGetKeyValue(subsection, MT_GUNNER_SECTION, MT_GUNNER_SECTION2, MT_GUNNER_SECTION3, MT_GUNNER_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esGunnerAbility[type].g_iHumanAmmo, value, 0, 99999);
		g_esGunnerAbility[type].g_iHumanCooldown = iGetKeyValue(subsection, MT_GUNNER_SECTION, MT_GUNNER_SECTION2, MT_GUNNER_SECTION3, MT_GUNNER_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esGunnerAbility[type].g_iHumanCooldown, value, 0, 99999);
		g_esGunnerAbility[type].g_iHumanMode = iGetKeyValue(subsection, MT_GUNNER_SECTION, MT_GUNNER_SECTION2, MT_GUNNER_SECTION3, MT_GUNNER_SECTION4, key, "HumanMode", "Human Mode", "Human_Mode", "hmode", g_esGunnerAbility[type].g_iHumanMode, value, 0, 1);
		g_esGunnerAbility[type].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_GUNNER_SECTION, MT_GUNNER_SECTION2, MT_GUNNER_SECTION3, MT_GUNNER_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esGunnerAbility[type].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esGunnerAbility[type].g_iRequiresHumans = iGetKeyValue(subsection, MT_GUNNER_SECTION, MT_GUNNER_SECTION2, MT_GUNNER_SECTION3, MT_GUNNER_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esGunnerAbility[type].g_iRequiresHumans, value, 0, 32);
		g_esGunnerAbility[type].g_iGunnerAbility = iGetKeyValue(subsection, MT_GUNNER_SECTION, MT_GUNNER_SECTION2, MT_GUNNER_SECTION3, MT_GUNNER_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esGunnerAbility[type].g_iGunnerAbility, value, 0, 1);
		g_esGunnerAbility[type].g_iGunnerMessage = iGetKeyValue(subsection, MT_GUNNER_SECTION, MT_GUNNER_SECTION2, MT_GUNNER_SECTION3, MT_GUNNER_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esGunnerAbility[type].g_iGunnerMessage, value, 0, 1);
		g_esGunnerAbility[type].g_flGunnerAccuracy = flGetKeyValue(subsection, MT_GUNNER_SECTION, MT_GUNNER_SECTION2, MT_GUNNER_SECTION3, MT_GUNNER_SECTION4, key, "GunnerAccuracy", "Gunner Accuracy", "Gunner_Accuracy", "accuracy", g_esGunnerAbility[type].g_flGunnerAccuracy, value, 0.1, 5.0);
		g_esGunnerAbility[type].g_iGunnerBullets = iGetKeyValue(subsection, MT_GUNNER_SECTION, MT_GUNNER_SECTION2, MT_GUNNER_SECTION3, MT_GUNNER_SECTION4, key, "GunnerBullets", "Gunner Bullets", "Gunner_Bullets", "bullets", g_esGunnerAbility[type].g_iGunnerBullets, value, 1, 99999);
		g_esGunnerAbility[type].g_flGunnerChance = flGetKeyValue(subsection, MT_GUNNER_SECTION, MT_GUNNER_SECTION2, MT_GUNNER_SECTION3, MT_GUNNER_SECTION4, key, "GunnerChance", "Gunner Chance", "Gunner_Chance", "chance", g_esGunnerAbility[type].g_flGunnerChance, value, 0.0, 100.0);
		g_esGunnerAbility[type].g_iGunnerClipSize = iGetKeyValue(subsection, MT_GUNNER_SECTION, MT_GUNNER_SECTION2, MT_GUNNER_SECTION3, MT_GUNNER_SECTION4, key, "GunnerClipSize", "Gunner Clip Size", "Gunner_Clip_Size", "clipsize", g_esGunnerAbility[type].g_iGunnerClipSize, value, 1, 99999);
		g_esGunnerAbility[type].g_iGunnerCooldown = iGetKeyValue(subsection, MT_GUNNER_SECTION, MT_GUNNER_SECTION2, MT_GUNNER_SECTION3, MT_GUNNER_SECTION4, key, "GunnerCooldown", "Gunner Cooldown", "Gunner_Cooldown", "cooldown", g_esGunnerAbility[type].g_iGunnerCooldown, value, 0, 99999);
		g_esGunnerAbility[type].g_flGunnerDamage = flGetKeyValue(subsection, MT_GUNNER_SECTION, MT_GUNNER_SECTION2, MT_GUNNER_SECTION3, MT_GUNNER_SECTION4, key, "GunnerDamage", "Gunner Damage", "Gunner_Damage", "damage", g_esGunnerAbility[type].g_flGunnerDamage, value, 0.0, 99999.0);
		g_esGunnerAbility[type].g_flGunnerDuration = flGetKeyValue(subsection, MT_GUNNER_SECTION, MT_GUNNER_SECTION2, MT_GUNNER_SECTION3, MT_GUNNER_SECTION4, key, "GunnerDuration", "Gunner Duration", "Gunner_Duration", "duration", g_esGunnerAbility[type].g_flGunnerDuration, value, 0.1, 99999.0);
		g_esGunnerAbility[type].g_iGunnerGlow = iGetKeyValue(subsection, MT_GUNNER_SECTION, MT_GUNNER_SECTION2, MT_GUNNER_SECTION3, MT_GUNNER_SECTION4, key, "GunnerGlow", "Gunner Glow", "Gunner_Glow", "glow", g_esGunnerAbility[type].g_iGunnerGlow, value, 0, 1);
		g_esGunnerAbility[type].g_iGunnerGunType = iGetKeyValue(subsection, MT_GUNNER_SECTION, MT_GUNNER_SECTION2, MT_GUNNER_SECTION3, MT_GUNNER_SECTION4, key, "GunnerGunType", "Gunner Gun Type", "Gunner_Gun_Type", "guntype", g_esGunnerAbility[type].g_iGunnerGunType, value, 0, (g_bSecondGame ? 18 : 6));
		g_esGunnerAbility[type].g_flGunnerInterval = flGetKeyValue(subsection, MT_GUNNER_SECTION, MT_GUNNER_SECTION2, MT_GUNNER_SECTION3, MT_GUNNER_SECTION4, key, "GunnerInterval", "Gunner Interval", "Gunner_Interval", "interval", g_esGunnerAbility[type].g_flGunnerInterval, value, 0.1, 99999.0);
		g_esGunnerAbility[type].g_flGunnerLoadTime = flGetKeyValue(subsection, MT_GUNNER_SECTION, MT_GUNNER_SECTION2, MT_GUNNER_SECTION3, MT_GUNNER_SECTION4, key, "GunnerLoadTime", "Gunner Load Time", "Gunner_Load_Time", "loadtime", g_esGunnerAbility[type].g_flGunnerLoadTime, value, 0.1, 99999.0);
		g_esGunnerAbility[type].g_flGunnerRange = flGetKeyValue(subsection, MT_GUNNER_SECTION, MT_GUNNER_SECTION2, MT_GUNNER_SECTION3, MT_GUNNER_SECTION4, key, "GunnerRange", "Gunner Range", "Gunner_Range", "range", g_esGunnerAbility[type].g_flGunnerRange, value, 1.0, 99999.0);
		g_esGunnerAbility[type].g_flGunnerReactionTime = flGetKeyValue(subsection, MT_GUNNER_SECTION, MT_GUNNER_SECTION2, MT_GUNNER_SECTION3, MT_GUNNER_SECTION4, key, "GunnerReactionTime", "Gunner Reaction Time", "Gunner_Reaction_Time", "reactiontime", g_esGunnerAbility[type].g_flGunnerReactionTime, value, 0.1, 99999.0);
		g_esGunnerAbility[type].g_iGunnerTargetType = iGetKeyValue(subsection, MT_GUNNER_SECTION, MT_GUNNER_SECTION2, MT_GUNNER_SECTION3, MT_GUNNER_SECTION4, key, "GunnerTargetType", "Gunner Target Type", "Gunner_Target_Type", "targettype", g_esGunnerAbility[type].g_iGunnerTargetType, value, 0, 31);
		g_esGunnerAbility[type].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_GUNNER_SECTION, MT_GUNNER_SECTION2, MT_GUNNER_SECTION3, MT_GUNNER_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esGunnerAbility[type].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_GUNNER_SECTION, MT_GUNNER_SECTION2, MT_GUNNER_SECTION3, MT_GUNNER_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}
}

#if defined MT_ABILITIES_MAIN
void vGunnerSettingsCached(int tank, bool apply, int type)
#else
public void MT_OnSettingsCached(int tank, bool apply, int type)
#endif
{
	bool bHuman = bIsTank(tank, MT_CHECK_FAKECLIENT);
	g_esGunnerCache[tank].g_flCloseAreasOnly = flGetSettingValue(apply, bHuman, g_esGunnerPlayer[tank].g_flCloseAreasOnly, g_esGunnerAbility[type].g_flCloseAreasOnly);
	g_esGunnerCache[tank].g_iComboAbility = iGetSettingValue(apply, bHuman, g_esGunnerPlayer[tank].g_iComboAbility, g_esGunnerAbility[type].g_iComboAbility);
	g_esGunnerCache[tank].g_flGunnerAccuracy = flGetSettingValue(apply, bHuman, g_esGunnerPlayer[tank].g_flGunnerAccuracy, g_esGunnerAbility[type].g_flGunnerAccuracy);
	g_esGunnerCache[tank].g_flGunnerChance = flGetSettingValue(apply, bHuman, g_esGunnerPlayer[tank].g_flGunnerChance, g_esGunnerAbility[type].g_flGunnerChance);
	g_esGunnerCache[tank].g_flGunnerDamage = flGetSettingValue(apply, bHuman, g_esGunnerPlayer[tank].g_flGunnerDamage, g_esGunnerAbility[type].g_flGunnerDamage);
	g_esGunnerCache[tank].g_flGunnerDuration = flGetSettingValue(apply, bHuman, g_esGunnerPlayer[tank].g_flGunnerDuration, g_esGunnerAbility[type].g_flGunnerDuration);
	g_esGunnerCache[tank].g_flGunnerInterval = flGetSettingValue(apply, bHuman, g_esGunnerPlayer[tank].g_flGunnerInterval, g_esGunnerAbility[type].g_flGunnerInterval);
	g_esGunnerCache[tank].g_flGunnerLoadTime = flGetSettingValue(apply, bHuman, g_esGunnerPlayer[tank].g_flGunnerLoadTime, g_esGunnerAbility[type].g_flGunnerLoadTime);
	g_esGunnerCache[tank].g_flGunnerRange = flGetSettingValue(apply, bHuman, g_esGunnerPlayer[tank].g_flGunnerRange, g_esGunnerAbility[type].g_flGunnerRange);
	g_esGunnerCache[tank].g_flGunnerReactionTime = flGetSettingValue(apply, bHuman, g_esGunnerPlayer[tank].g_flGunnerReactionTime, g_esGunnerAbility[type].g_flGunnerReactionTime);
	g_esGunnerCache[tank].g_iHumanAbility = iGetSettingValue(apply, bHuman, g_esGunnerPlayer[tank].g_iHumanAbility, g_esGunnerAbility[type].g_iHumanAbility);
	g_esGunnerCache[tank].g_iHumanAmmo = iGetSettingValue(apply, bHuman, g_esGunnerPlayer[tank].g_iHumanAmmo, g_esGunnerAbility[type].g_iHumanAmmo);
	g_esGunnerCache[tank].g_iHumanCooldown = iGetSettingValue(apply, bHuman, g_esGunnerPlayer[tank].g_iHumanCooldown, g_esGunnerAbility[type].g_iHumanCooldown);
	g_esGunnerCache[tank].g_iHumanMode = iGetSettingValue(apply, bHuman, g_esGunnerPlayer[tank].g_iHumanMode, g_esGunnerAbility[type].g_iHumanMode);
	g_esGunnerCache[tank].g_iGunnerAbility = iGetSettingValue(apply, bHuman, g_esGunnerPlayer[tank].g_iGunnerAbility, g_esGunnerAbility[type].g_iGunnerAbility);
	g_esGunnerCache[tank].g_iGunnerBullets = iGetSettingValue(apply, bHuman, g_esGunnerPlayer[tank].g_iGunnerBullets, g_esGunnerAbility[type].g_iGunnerBullets);
	g_esGunnerCache[tank].g_iGunnerClipSize = iGetSettingValue(apply, bHuman, g_esGunnerPlayer[tank].g_iGunnerClipSize, g_esGunnerAbility[type].g_iGunnerClipSize);
	g_esGunnerCache[tank].g_iGunnerCooldown = iGetSettingValue(apply, bHuman, g_esGunnerPlayer[tank].g_iGunnerCooldown, g_esGunnerAbility[type].g_iGunnerCooldown);
	g_esGunnerCache[tank].g_iGunnerGlow = iGetSettingValue(apply, bHuman, g_esGunnerPlayer[tank].g_iGunnerGlow, g_esGunnerAbility[type].g_iGunnerGlow);
	g_esGunnerCache[tank].g_iGunnerGunType = iGetSettingValue(apply, bHuman, g_esGunnerPlayer[tank].g_iGunnerGunType, g_esGunnerAbility[type].g_iGunnerGunType);
	g_esGunnerCache[tank].g_iGunnerMessage = iGetSettingValue(apply, bHuman, g_esGunnerPlayer[tank].g_iGunnerMessage, g_esGunnerAbility[type].g_iGunnerMessage);
	g_esGunnerCache[tank].g_iGunnerTargetType = iGetSettingValue(apply, bHuman, g_esGunnerPlayer[tank].g_iGunnerTargetType, g_esGunnerAbility[type].g_iGunnerTargetType);
	g_esGunnerCache[tank].g_flOpenAreasOnly = flGetSettingValue(apply, bHuman, g_esGunnerPlayer[tank].g_flOpenAreasOnly, g_esGunnerAbility[type].g_flOpenAreasOnly);
	g_esGunnerCache[tank].g_iRequiresHumans = iGetSettingValue(apply, bHuman, g_esGunnerPlayer[tank].g_iRequiresHumans, g_esGunnerAbility[type].g_iRequiresHumans);
	g_esGunnerPlayer[tank].g_iTankType = apply ? type : 0;
}

#if defined MT_ABILITIES_MAIN
void vGunnerCopyStats(int oldTank, int newTank)
#else
public void MT_OnCopyStats(int oldTank, int newTank)
#endif
{
	vGunnerCopyStats2(oldTank, newTank);

	if (oldTank != newTank)
	{
		vRemoveGunner(oldTank);
	}
}

#if !defined MT_ABILITIES_MAIN
public void MT_OnPluginUpdate()
{
	MT_ReloadPlugin(null);
}
#endif

#if defined MT_ABILITIES_MAIN
void vGunnerEventFired(Event event, const char[] name)
#else
public void MT_OnEventFired(Event event, const char[] name, bool dontBroadcast)
#endif
{
	if (StrEqual(name, "bot_player_replace"))
	{
		int iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId),
			iTankId = event.GetInt("player"), iTank = GetClientOfUserId(iTankId);
		if (bIsValidClient(iBot) && bIsTank(iTank))
		{
			vGunnerCopyStats2(iBot, iTank);
			vRemoveGunner(iBot);
		}
	}
	else if (StrEqual(name, "player_bot_replace"))
	{
		int iTankId = event.GetInt("player"), iTank = GetClientOfUserId(iTankId),
			iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId);
		if (bIsValidClient(iTank) && bIsTank(iBot))
		{
			vGunnerCopyStats2(iTank, iBot);
			vRemoveGunner(iTank);
		}
	}
	else if (StrEqual(name, "player_death") || StrEqual(name, "player_spawn"))
	{
		int iTankId = event.GetInt("userid"), iTank = GetClientOfUserId(iTankId);
		if (MT_IsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME))
		{
			vRemoveGunner(iTank);
		}
	}
	else if (StrEqual(name, "player_hurt"))
	{
		int iVictimId = event.GetInt("userid"), iVictim = GetClientOfUserId(iVictimId),
			iAttackerId = event.GetInt("attacker"), iAttacker = GetClientOfUserId(iAttackerId);
		if (MT_IsTankSupported(iVictim))
		{
			int iTargetType = g_esGunnerCache[iVictim].g_iGunnerTargetType;
			if (bIsSurvivor(iAttacker))
			{
				bool bHuman = bIsValidClient(iAttacker, MT_CHECK_FAKECLIENT);
				if (iTargetType == 0 || (bHuman && (iTargetType & MT_GUNNER_HUMANS)) || (!bHuman && (iTargetType & MT_GUNNER_BOTS)) || (bIsPlayerIncapacitated(iAttacker) && (iTargetType & MT_GUNNER_INCAPPED)))
				{
					g_esGunnerPlayer[iVictim].g_flDroneScanTime = GetEngineTime();
					g_esGunnerPlayer[iVictim].g_iSurvivorEnemy = iAttacker;
				}
			}
			else if (bIsInfected(iAttacker) && (iTargetType == 0 || (iTargetType & MT_GUNNER_SPECIAL)))
			{
				g_esGunnerPlayer[iVictim].g_flDroneScanTime = GetEngineTime();
				g_esGunnerPlayer[iVictim].g_iSpecialEnemy = iAttacker;
			}
			else
			{
				int iEntity = event.GetInt("attackerentid");
				if (bIsCommonInfected(iEntity) && (iTargetType == 0 || (iTargetType & MT_GUNNER_COMMON)))
				{
					g_esGunnerPlayer[iVictim].g_iCommonEnemy = iEntity;
				}
			}
		}
	}
	else if (StrEqual(name, "mission_lost") || StrEqual(name, "round_start") || StrEqual(name, "round_end"))
	{
		vGunnerReset();
	}
}

#if defined MT_ABILITIES_MAIN
void vGunnerAbilityActivated(int tank)
#else
public void MT_OnAbilityActivated(int tank)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esGunnerAbility[g_esGunnerPlayer[tank].g_iTankType].g_iAccessFlags, g_esGunnerPlayer[tank].g_iAccessFlags)) || g_esGunnerCache[tank].g_iHumanAbility == 0))
	{
		return;
	}

	if (MT_IsTankSupported(tank) && (!bIsTank(tank, MT_CHECK_FAKECLIENT) || g_esGunnerCache[tank].g_iHumanAbility != 1) && MT_IsCustomTankSupported(tank) && g_esGunnerCache[tank].g_iGunnerAbility == 1 && g_esGunnerCache[tank].g_iComboAbility == 0 && !g_esGunnerPlayer[tank].g_bActivated)
	{
		vGunnerAbility(tank);
	}
}

#if defined MT_ABILITIES_MAIN
void vGunnerButtonPressed(int tank, int button)
#else
public void MT_OnButtonPressed(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && MT_IsCustomTankSupported(tank))
	{
		if (bIsAreaNarrow(tank, g_esGunnerCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esGunnerCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esGunnerPlayer[tank].g_iTankType) || (g_esGunnerCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esGunnerCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esGunnerAbility[g_esGunnerPlayer[tank].g_iTankType].g_iAccessFlags, g_esGunnerPlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		if ((button & MT_MAIN_KEY) && g_esGunnerCache[tank].g_iGunnerAbility == 1 && g_esGunnerCache[tank].g_iHumanAbility == 1)
		{
			int iTime = GetTime();
			bool bRecharging = g_esGunnerPlayer[tank].g_iCooldown != -1 && g_esGunnerPlayer[tank].g_iCooldown > iTime;

			switch (g_esGunnerCache[tank].g_iHumanMode)
			{
				case 0:
				{
					if (!g_esGunnerPlayer[tank].g_bActivated && !bRecharging)
					{
						vGunnerAbility(tank);
					}
					else if (g_esGunnerPlayer[tank].g_bActivated)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "GunnerHuman3");
					}
					else if (bRecharging)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "GunnerHuman4", (g_esGunnerPlayer[tank].g_iCooldown - iTime));
					}
				}
				case 1:
				{
					if (g_esGunnerPlayer[tank].g_iAmmoCount < g_esGunnerCache[tank].g_iHumanAmmo && g_esGunnerCache[tank].g_iHumanAmmo > 0)
					{
						if (!g_esGunnerPlayer[tank].g_bActivated && !bRecharging)
						{
							g_esGunnerPlayer[tank].g_bActivated = true;
							g_esGunnerPlayer[tank].g_iAmmoCount++;

							vGunner2(tank);
							MT_PrintToChat(tank, "%s %t", MT_TAG3, "GunnerHuman", g_esGunnerPlayer[tank].g_iAmmoCount, g_esGunnerCache[tank].g_iHumanAmmo);
						}
						else if (g_esGunnerPlayer[tank].g_bActivated)
						{
							MT_PrintToChat(tank, "%s %t", MT_TAG3, "GunnerHuman3");
						}
						else if (bRecharging)
						{
							MT_PrintToChat(tank, "%s %t", MT_TAG3, "GunnerHuman4", (g_esGunnerPlayer[tank].g_iCooldown - iTime));
						}
					}
					else
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "GunnerAmmo");
					}
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vGunnerButtonReleased(int tank, int button)
#else
public void MT_OnButtonReleased(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && g_esGunnerCache[tank].g_iHumanAbility == 1)
	{
		if ((button & MT_MAIN_KEY) && g_esGunnerCache[tank].g_iHumanMode == 1 && g_esGunnerPlayer[tank].g_bActivated && (g_esGunnerPlayer[tank].g_iCooldown == -1 || g_esGunnerPlayer[tank].g_iCooldown < GetTime()))
		{
			vGunnerReset2(tank);
			vGunnerReset3(tank);
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vGunnerChangeType(int tank, int oldType)
#else
public void MT_OnChangeType(int tank, int oldType, int newType, bool revert)
#endif
{
	if (oldType <= 0)
	{
		return;
	}

	vRemoveGunner(tank);
}

void vGunner(int tank)
{
	int iTime = GetTime();
	if (g_esGunnerPlayer[tank].g_iCooldown != -1 && g_esGunnerPlayer[tank].g_iCooldown > iTime)
	{
		return;
	}

	g_esGunnerPlayer[tank].g_bActivated = true;

	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esGunnerCache[tank].g_iHumanAbility == 1)
	{
		g_esGunnerPlayer[tank].g_iAmmoCount++;

		MT_PrintToChat(tank, "%s %t", MT_TAG3, "GunnerHuman", g_esGunnerPlayer[tank].g_iAmmoCount, g_esGunnerCache[tank].g_iHumanAmmo);
	}

	vGunner2(tank);
}

void vGunner2(int tank)
{
	int iType = g_esGunnerCache[tank].g_iGunnerGunType, iDifference = g_bSecondGame ? 1 : 13;
	g_esGunnerPlayer[tank].g_iGunType = (iType > 0) ? (iType - 1) : MT_GetRandomInt(0, (sizeof g_sWeaponModels - iDifference));

	float flAngles[3], flOrigin[3], flPos[3];
	GetClientEyePosition(tank, flOrigin);
	GetClientEyeAngles(tank, flAngles);

	TR_TraceRayFilter(flOrigin, flAngles, MASK_SOLID, RayType_Infinite, bTraceRayDontHitSelfAndSolid);
	if (TR_DidHit())
	{
		TR_GetEndPosition(flPos);
	}

	float flVector1[3], flVector2[3];
	SubtractVectors(flOrigin, flPos, flVector1);
	NormalizeVector(flVector1, flVector2);
	ScaleVector(flVector2, 50.0);
	AddVectors(flPos, flVector2, flVector1);

	char sTemp[128];
	int iGun = CreateEntityByName(g_sWeaponModels[g_esGunnerPlayer[tank].g_iGunType]);
	if (bIsValidEntity(iGun))
	{
		DispatchSpawn(iGun);
		GetEntPropString(iGun, Prop_Data, "m_ModelName", sTemp, sizeof sTemp);
		RemoveEntity(iGun);
	}

	int iDrone = CreateEntityByName("prop_dynamic_override");
	if (bIsValidEntity(iDrone))
	{
		DispatchKeyValue(iDrone, "solid", "6");
		DispatchKeyValue(iDrone, "model", sTemp);

		if (g_esGunnerCache[tank].g_iGunnerGlow == 1)
		{
			int iGlowColor[4];
			MT_GetTankColors(tank, 2, iGlowColor[0], iGlowColor[1], iGlowColor[2], iGlowColor[3]);

			switch (iGlowColor[0] == -2 && iGlowColor[1] == -2 && iGlowColor[2] == -2)
			{
				case true:
				{
					if (!g_esGunnerPlayer[tank].g_bRainbowColor)
					{
						g_esGunnerPlayer[tank].g_bRainbowColor = SDKHookEx(tank, SDKHook_PreThinkPost, OnGunnerPreThinkPost);
					}
				}
				case false: vSetGunnerGlow(iDrone, iGetRGBColor(iGlowColor[0], iGlowColor[1], iGlowColor[2]), !!MT_IsGlowFlashing(tank), MT_GetGlowRange(tank, false), MT_GetGlowRange(tank, true), ((MT_GetGlowType(tank) == 1) ? 3 : 2));
			}
		}

		TeleportEntity(iDrone, flVector1);
		DispatchSpawn(iDrone);

		SetEntProp(iDrone, Prop_Send, "m_CollisionGroup", 1);
		SetEntityMoveType(iDrone, MOVETYPE_FLY);

		SetVariantString("idle");
		AcceptEntityInput(iDrone, "SetAnimation");
		SetVariantString("idle");
		AcceptEntityInput(iDrone, "SetDefaultAnimation");

		MT_HideEntity(iDrone, true);
	}

	g_esGunnerPlayer[tank].g_bReloadingDrone = false;
	g_esGunnerPlayer[tank].g_flDroneFireTime = 0.0;
	g_esGunnerPlayer[tank].g_flDroneReloadTime = 0.0;
	g_esGunnerPlayer[tank].g_flDroneScanTime = 0.0;
	g_esGunnerPlayer[tank].g_iCommonEnemy = INVALID_ENT_REFERENCE;
	g_esGunnerPlayer[tank].g_iDrone = EntIndexToEntRef(iDrone);
	g_esGunnerPlayer[tank].g_iDroneBullets = 0;
	g_esGunnerPlayer[tank].g_iSpecialEnemy = 0;
	g_esGunnerPlayer[tank].g_iSurvivorEnemy = 0;
}

void vGunner3(int tank, float time, float duration)
{
	int iDrone = EntRefToEntIndex(g_esGunnerPlayer[tank].g_iDrone);
	if (bIsValidEntity(iDrone))
	{
		if (bIsTank(tank))
		{
			g_esGunnerPlayer[tank].g_flDroneLifetime += duration;

			int iPos = g_esGunnerAbility[g_esGunnerPlayer[tank].g_iTankType].g_iComboPosition;
			float flDuration = (iPos != -1) ? MT_GetCombinationSetting(tank, 5, iPos) : g_esGunnerCache[tank].g_flGunnerDuration;
			if (-1.0 < flDuration < g_esGunnerPlayer[tank].g_flDroneLifetime)
			{
				vRemoveGunner(tank);

				return;
			}

			float flPos[3];
			GetEntPropVector(iDrone, Prop_Send, "m_vecOrigin", flPos);
			int iTargetType = g_esGunnerCache[tank].g_iGunnerTargetType, iTarget = 0;
			if ((time - g_esGunnerPlayer[tank].g_flDroneScanTime) > g_esGunnerCache[tank].g_flGunnerReactionTime)
			{
				g_esGunnerPlayer[tank].g_flDroneScanTime = time;

				float flRange = (iPos != -1) ? MT_GetCombinationSetting(tank, 9, iPos) : g_esGunnerCache[tank].g_flGunnerRange;
				if (iTargetType == 0 || (iTargetType & MT_GUNNER_HUMANS) || (iTargetType & MT_GUNNER_BOTS) || (iTargetType & MT_GUNNER_INCAPPED))
				{
					g_esGunnerPlayer[tank].g_iSurvivorEnemy = iGetNearestSurvivor(tank, flPos, flRange, (iTargetType != 0 && !(iTargetType & MT_GUNNER_HUMANS)), (iTargetType != 0 && !(iTargetType & MT_GUNNER_BOTS)), (iTargetType != 0 && !(iTargetType & MT_GUNNER_INCAPPED)));
				}

				if (iTargetType == 0 || (iTargetType & MT_GUNNER_SPECIAL))
				{
					g_esGunnerPlayer[tank].g_iSpecialEnemy = iGetNearestSpecialInfected(tank, flPos, flRange);
				}

				if (iTargetType == 0 || (iTargetType & MT_GUNNER_COMMON))
				{
					g_esGunnerPlayer[tank].g_iCommonEnemy = iGetNearestCommonInfected(tank, flPos, flRange);
				}
			}

			bool bFound = false;
			float flOrigin[3], flAngles[3];
			if (bIsSurvivor(g_esGunnerPlayer[tank].g_iSurvivorEnemy))
			{
				bFound = true;
				iTarget = g_esGunnerPlayer[tank].g_iSurvivorEnemy;

				float flEyePos[3];
				GetClientEyePosition(g_esGunnerPlayer[tank].g_iSurvivorEnemy, flEyePos);
				GetClientAbsOrigin(g_esGunnerPlayer[tank].g_iSurvivorEnemy, g_esGunnerPlayer[tank].g_flEnemyOrigin);
				flOrigin[0] = (g_esGunnerPlayer[tank].g_flEnemyOrigin[0] * 0.4) + (flEyePos[0] * 0.6);
				flOrigin[1] = (g_esGunnerPlayer[tank].g_flEnemyOrigin[1] * 0.4) + (flEyePos[1] * 0.6);
				flOrigin[2] = (g_esGunnerPlayer[tank].g_flEnemyOrigin[2] * 0.4) + (flEyePos[2] * 0.6);

				SubtractVectors(flOrigin, flPos, flAngles);
				GetVectorAngles(flAngles, flAngles);
			}
			else
			{
				g_esGunnerPlayer[tank].g_iSurvivorEnemy = 0;
			}

			if (!bFound)
			{
				if (bIsInfected(g_esGunnerPlayer[tank].g_iSpecialEnemy) && (iTargetType == 0 || (iTargetType & MT_GUNNER_SPECIAL)))
				{
					bFound = true;
					iTarget = g_esGunnerPlayer[tank].g_iSpecialEnemy;

					float flEyePos[3];
					GetClientEyePosition(g_esGunnerPlayer[tank].g_iSpecialEnemy, flEyePos);
					GetClientAbsOrigin(g_esGunnerPlayer[tank].g_iSpecialEnemy, g_esGunnerPlayer[tank].g_flEnemyOrigin);
					flOrigin[0] = (g_esGunnerPlayer[tank].g_flEnemyOrigin[0] * 0.4) + (flEyePos[0] * 0.6);
					flOrigin[1] = (g_esGunnerPlayer[tank].g_flEnemyOrigin[1] * 0.4) + (flEyePos[1] * 0.6);
					flOrigin[2] = (g_esGunnerPlayer[tank].g_flEnemyOrigin[2] * 0.4) + (flEyePos[2] * 0.6);

					SubtractVectors(flOrigin, flPos, flAngles);
					GetVectorAngles(flAngles, flAngles);
				}
				else
				{
					g_esGunnerPlayer[tank].g_iSpecialEnemy = 0;
				}
			}

			if (!bFound)
			{
				if (bIsCommonInfected(g_esGunnerPlayer[tank].g_iCommonEnemy) && (iTargetType == 0 || (iTargetType & MT_GUNNER_COMMON)))
				{
					bFound = true;
					iTarget = g_esGunnerPlayer[tank].g_iCommonEnemy;

					GetEntPropVector(g_esGunnerPlayer[tank].g_iCommonEnemy, Prop_Send, "m_vecOrigin", flOrigin);
					flOrigin[2] += 40.0;
					SubtractVectors(flOrigin, flPos, flAngles);
					GetVectorAngles(flAngles, flAngles);
				}
				else
				{
					g_esGunnerPlayer[tank].g_iCommonEnemy = INVALID_ENT_REFERENCE;
				}
			}

			if (g_esGunnerPlayer[tank].g_bReloadingDrone)
			{
				if (g_esGunnerPlayer[tank].g_iDroneBullets >= g_esGunnerCache[tank].g_iGunnerClipSize && (time - g_esGunnerPlayer[tank].g_flDroneReloadTime > g_esGunnerCache[tank].g_flGunnerLoadTime))
				{
					g_esGunnerPlayer[tank].g_bReloadingDrone = false;
					g_esGunnerPlayer[tank].g_flDroneReloadTime = time;

					EmitSoundToAll(g_sWeaponSounds[20], SOUND_FROM_WORLD, SNDCHAN_WEAPON, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, .origin = flPos, .updatePos = false);
				}
				else if ((time - g_esGunnerPlayer[tank].g_flDroneReloadTime) > g_esGunnerCache[tank].g_flGunnerLoadTime)
				{
					g_esGunnerPlayer[tank].g_flDroneReloadTime = time;
					g_esGunnerPlayer[tank].g_iDroneBullets += g_esGunnerCache[tank].g_iGunnerClipSize;

					EmitSoundToAll(g_sWeaponSounds[19], SOUND_FROM_WORLD, SNDCHAN_WEAPON, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, .origin = flPos, .updatePos = false);
				}
			}

			if (!g_esGunnerPlayer[tank].g_bReloadingDrone && !bFound && g_esGunnerPlayer[tank].g_iDroneBullets < g_esGunnerCache[tank].g_iGunnerClipSize)
			{
				g_esGunnerPlayer[tank].g_bReloadingDrone = true;
				g_esGunnerPlayer[tank].g_flDroneReloadTime = 0.0;

				if (!g_bWeaponDisrupt[g_esGunnerPlayer[tank].g_iGunType])
				{
					g_esGunnerPlayer[tank].g_iDroneBullets = 0;
				}
			}

			float flInterval = (iPos != -1) ? MT_GetCombinationSetting(tank, 6, iPos) : g_esGunnerCache[tank].g_flGunnerInterval;
			if (!g_esGunnerPlayer[tank].g_bReloadingDrone && bFound && (time - g_esGunnerPlayer[tank].g_flDroneFireTime) > flInterval)
			{
				if (g_esGunnerPlayer[tank].g_iDroneBullets > 0)
				{
					g_esGunnerPlayer[tank].g_bReloadingDrone = false;
					g_esGunnerPlayer[tank].g_flDroneFireTime = time;
					g_esGunnerPlayer[tank].g_iDroneBullets--;

					vGunner4(tank, iTarget, iDrone, flOrigin, flPos);
				}
				else
				{
					g_esGunnerPlayer[tank].g_bReloadingDrone = true;
					g_esGunnerPlayer[tank].g_flDroneFireTime = time;
					g_esGunnerPlayer[tank].g_flDroneReloadTime = time;

					EmitSoundToAll(g_sWeaponSounds[18], SOUND_FROM_WORLD, SNDCHAN_WEAPON, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, .origin = flPos, .updatePos = false);
				}
			}

			float flEyePos[3], flVelocity[3];
 			GetClientEyePosition(tank, flEyePos);
			flEyePos[2] += 30.0;

			float flDistance = GetVectorDistance(flPos, flEyePos);
			if (flDistance > 500.0)
			{
				TeleportEntity(iDrone, flEyePos, flAngles);
			}
			else if (flDistance > 100.0)
			{
				g_esGunnerPlayer[tank].g_flDroneWalkTime = time;

				MakeVectorFromPoints(flPos, flEyePos, flVelocity);
				NormalizeVector(flVelocity, flVelocity);
				ScaleVector(flVelocity, (5.0 * flDistance));

				if (!bFound)
				{
					GetVectorAngles(flVelocity, flAngles);
				}

				TeleportEntity(iDrone, .angles = flAngles, .velocity = flVelocity);
			}
			else
			{
				flVelocity[0] = flVelocity[1] = flVelocity[2] = 0.0;
				if (!bFound && (time - g_esGunnerPlayer[tank].g_flDroneFireTime) > 4.0 && (time - g_esGunnerPlayer[tank].g_flDroneWalkTime) > 1.0)
				{
					flAngles[1] += 5.0;
				}

				TeleportEntity(iDrone, .angles = flAngles, .velocity = flVelocity);
			}
		}
		else
		{
			vRemoveGunner(tank);
		}
	}
	else
	{
		g_esGunnerPlayer[tank].g_flDroneLifetime -= (duration * 0.5);
		if (g_esGunnerPlayer[tank].g_flDroneLifetime < 0.0)
		{
			g_esGunnerPlayer[tank].g_flDroneLifetime = 0.0;
		}
	}
}

void vGunner4(int tank, int target, int drone, float pos[3], float origin[3])
{
	float flPos[3], flAngles[3], flAngles2[3];
	SubtractVectors(pos, origin, pos);
	GetVectorAngles(pos, flAngles);

	int iPos = g_esGunnerAbility[g_esGunnerPlayer[tank].g_iTankType].g_iComboPosition;
	float flDamage = (iPos != -1) ? MT_GetCombinationSetting(tank, 3, iPos) : g_esGunnerCache[tank].g_flGunnerDamage;
	if (flDamage > 0.0)
	{
		float flAccuracy = g_esGunnerCache[tank].g_flGunnerAccuracy, flDifference = (0.0 - flAccuracy), flDirection[3], flVector1[3], flVector2[3];
		int iTarget = 0;
		for (int iCount = 0; iCount < g_esGunnerCache[tank].g_iGunnerBullets; iCount++)
		{
			flAngles2[0] = (flAngles[0] + GetRandomFloat(flDifference, flAccuracy));
			flAngles2[1] = (flAngles[1] + GetRandomFloat(flDifference, flAccuracy));
			flAngles2[2] = (flAngles[2] + GetRandomFloat(flDifference, flAccuracy));

			if (bIsSurvivor(target))
			{
				TR_TraceRayFilter(origin, flAngles2, MASK_SOLID, RayType_Infinite, bTraceRayDontHitSelfAndInfected, drone);
			}
			else if (bIsInfected(target))
			{
				TR_TraceRayFilter(origin, flAngles2, MASK_SOLID, RayType_Infinite, bTraceRayDontHitSelfAndSurvivor, drone);
			}
			else if (bIsCommonInfected(target))
			{
				TR_TraceRayFilter(origin, flAngles2, MASK_SOLID, RayType_Infinite, bTraceRayDontHitSelfAndPlayer, drone);
			}

			if (TR_DidHit())
			{
				TR_GetEndPosition(flPos);
				iTarget = TR_GetEntityIndex();

				flDirection[0] = GetRandomFloat(-1.0, 1.0);
				flDirection[1] = GetRandomFloat(-1.0, 1.0);
				flDirection[2] = GetRandomFloat(-1.0, 1.0);

				TE_SetupSparks(flPos, flDirection, 1, 3);
				TE_SendToAll();
			}

			if (iTarget > 0)
			{
				SDKHooks_TakeDamage(iTarget, drone, tank, MT_GetScaledDamage(flDamage), DMG_BULLET, drone);
			}

			SubtractVectors(origin, flPos, flVector1);
			NormalizeVector(flVector1, flVector2);
			ScaleVector(flVector2, 36.0);
			SubtractVectors(origin, flVector2, g_esGunnerPlayer[tank].g_flEnemyOrigin);

			TE_SetupBeamPoints(g_esGunnerPlayer[tank].g_flEnemyOrigin, flPos, g_iGunnerSprite, 0, 0, 0, 0.06, 0.01, (g_bSecondGame ? 0.08 : 0.3), 1, 0.0, {200, 200, 200, 230}, 0);
			TE_SendToAll();

			EmitSoundToAll(g_sWeaponSounds[g_esGunnerPlayer[tank].g_iGunType], SOUND_FROM_WORLD, SNDCHAN_WEAPON, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, .origin = origin, .updatePos = false);
		}
	}
}

void vGunnerAbility(int tank)
{
	if ((g_esGunnerPlayer[tank].g_iCooldown != -1 && g_esGunnerPlayer[tank].g_iCooldown > GetTime()) || bIsAreaNarrow(tank, g_esGunnerCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esGunnerCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esGunnerPlayer[tank].g_iTankType) || (g_esGunnerCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esGunnerCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esGunnerAbility[g_esGunnerPlayer[tank].g_iTankType].g_iAccessFlags, g_esGunnerPlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (g_esGunnerPlayer[tank].g_iAmmoCount < g_esGunnerCache[tank].g_iHumanAmmo && g_esGunnerCache[tank].g_iHumanAmmo > 0))
	{
		if (MT_GetRandomFloat(0.1, 100.0) <= g_esGunnerCache[tank].g_flGunnerChance && !g_esGunnerPlayer[tank].g_bActivated)
		{
			vGunner(tank);
		}
		else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esGunnerCache[tank].g_iHumanAbility == 1)
		{
			MT_PrintToChat(tank, "%s %t", MT_TAG3, "GunnerHuman2");
		}
	}
	else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esGunnerCache[tank].g_iHumanAbility == 1)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "GunnerAmmo");
	}
}

void OnGunnerPreThinkPost(int tank)
{
	if (!g_bSecondGame || !MT_IsTankSupported(tank) || !MT_IsCustomTankSupported(tank) || !g_esGunnerPlayer[tank].g_bRainbowColor)
	{
		g_esGunnerPlayer[tank].g_bRainbowColor = false;

		SDKUnhook(tank, SDKHook_PreThinkPost, OnGunnerPreThinkPost);

		return;
	}

	int iDrone = EntRefToEntIndex(g_esGunnerPlayer[tank].g_iDrone);
	if (iDrone == INVALID_ENT_REFERENCE || !bIsValidEntity(iDrone))
	{
		g_esGunnerPlayer[tank].g_bRainbowColor = false;

		SDKUnhook(tank, SDKHook_PreThinkPost, OnGunnerPreThinkPost);

		return;
	}

	bool bHook = false;
	int iColor[4];
	iColor[0] = RoundToNearest((Cosine((GetGameTime() * 1.0) + tank) * 127.5) + 127.5);
	iColor[1] = RoundToNearest((Cosine((GetGameTime() * 1.0) + tank + 2) * 127.5) + 127.5);
	iColor[2] = RoundToNearest((Cosine((GetGameTime() * 1.0) + tank + 4) * 127.5) + 127.5);
	iColor[3] = 50;

	int iTempColor[4];
	MT_GetTankColors(tank, 2, iTempColor[0], iTempColor[1], iTempColor[2], iTempColor[3]);
	if (iTempColor[0] == -2 && iTempColor[1] == -2 && iTempColor[2] == -2 && g_esGunnerCache[tank].g_iGunnerGlow == 1)
	{
		bHook = true;

		vSetGunnerGlow(iDrone, iGetRGBColor(iColor[0], iColor[1], iColor[2]), !!MT_IsGlowFlashing(tank), MT_GetGlowRange(tank, false), MT_GetGlowRange(tank, true), ((MT_GetGlowType(tank) == 1) ? 3 : 2));
	}

	if (!bHook)
	{
		g_esGunnerPlayer[tank].g_bRainbowColor = false;

		SDKUnhook(tank, SDKHook_PreThinkPost, OnGunnerPreThinkPost);
	}
}

void vGunnerCopyStats2(int oldTank, int newTank)
{
	g_esGunnerPlayer[newTank].g_iAmmoCount = g_esGunnerPlayer[oldTank].g_iAmmoCount;
	g_esGunnerPlayer[newTank].g_iCooldown = g_esGunnerPlayer[oldTank].g_iCooldown;
}

void vRemoveGunner(int tank)
{
	g_esGunnerPlayer[tank].g_bActivated = false;
	g_esGunnerPlayer[tank].g_bRainbowColor = false;
	g_esGunnerPlayer[tank].g_bReloadingDrone = false;
	g_esGunnerPlayer[tank].g_flDroneFireTime = 0.0;
	g_esGunnerPlayer[tank].g_flDroneLifetime = 0.0;
	g_esGunnerPlayer[tank].g_flDroneReloadTime = 0.0;
	g_esGunnerPlayer[tank].g_flDroneScanTime = 0.0;
	g_esGunnerPlayer[tank].g_flDroneWalkTime = 0.0;
	g_esGunnerPlayer[tank].g_iAmmoCount = 0;
	g_esGunnerPlayer[tank].g_iCooldown = -1;
	g_esGunnerPlayer[tank].g_iCommonEnemy = INVALID_ENT_REFERENCE;
	g_esGunnerPlayer[tank].g_iDroneBullets = 0;
	g_esGunnerPlayer[tank].g_iGunType = 0;
	g_esGunnerPlayer[tank].g_iSpecialEnemy = 0;
	g_esGunnerPlayer[tank].g_iSurvivorEnemy = 0;

	int iDrone = EntRefToEntIndex(g_esGunnerPlayer[tank].g_iDrone);
	if (bIsValidEntity(iDrone))
	{
		vSetGunnerGlow(iDrone, 0, 0, 0, 0, 0);
		MT_HideEntity(iDrone, false);
		RemoveEntity(iDrone);
	}

	g_esGunnerPlayer[tank].g_iDrone = INVALID_ENT_REFERENCE;
}

void vGunnerReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
		{
			vRemoveGunner(iPlayer);
		}
	}
}

void vGunnerReset2(int tank)
{
	vRemoveGunner(tank);

	if (g_esGunnerCache[tank].g_iGunnerMessage == 1)
	{
		char sTankName[33];
		MT_GetTankName(tank, sTankName);
		MT_PrintToChatAll("%s %t", MT_TAG2, "Gunner2", sTankName);
		MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Gunner2", LANG_SERVER, sTankName);
	}
}

void vGunnerReset3(int tank)
{
	int iTime = GetTime(), iPos = g_esGunnerAbility[g_esGunnerPlayer[tank].g_iTankType].g_iComboPosition, iCooldown = (iPos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 2, iPos)) : g_esGunnerCache[tank].g_iGunnerCooldown;
	iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esGunnerCache[tank].g_iHumanAbility == 1 && g_esGunnerCache[tank].g_iHumanMode == 0 && g_esGunnerPlayer[tank].g_iAmmoCount < g_esGunnerCache[tank].g_iHumanAmmo && g_esGunnerCache[tank].g_iHumanAmmo > 0) ? g_esGunnerCache[tank].g_iHumanCooldown : iCooldown;
	g_esGunnerPlayer[tank].g_iCooldown = (iTime + iCooldown);
	if (g_esGunnerPlayer[tank].g_iCooldown != -1 && g_esGunnerPlayer[tank].g_iCooldown > iTime)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "GunnerHuman5", (g_esGunnerPlayer[tank].g_iCooldown - iTime));
	}
}

void vSetGunnerGlow(int drone, int color, int flashing, int min, int max, int type)
{
	if (!g_bSecondGame)
	{
		return;
	}

	SetEntProp(drone, Prop_Send, "m_glowColorOverride", color);
	SetEntProp(drone, Prop_Send, "m_bFlashing", flashing);
	SetEntProp(drone, Prop_Send, "m_nGlowRangeMin", min);
	SetEntProp(drone, Prop_Send, "m_nGlowRange", max);
	SetEntProp(drone, Prop_Send, "m_iGlowType", type);
}

Action tTimerGunnerCombo(Handle timer, int userid)
{
	int iTank = GetClientOfUserId(userid);
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esGunnerAbility[g_esGunnerPlayer[iTank].g_iTankType].g_iAccessFlags, g_esGunnerPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esGunnerPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esGunnerCache[iTank].g_iGunnerAbility == 0 || g_esGunnerPlayer[iTank].g_bActivated)
	{
		return Plugin_Stop;
	}

	vGunner(iTank);

	return Plugin_Continue;
}