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

#define MT_DROP_COMPILE_METHOD 0 // 0: packaged, 1: standalone

#if !defined MT_ABILITIES_MAIN
	#if MT_DROP_COMPILE_METHOD == 1
		#include <sourcemod>
		#include <mutant_tanks>
	#else
		#error This file must be inside "scripting/mutant_tanks/abilities" while compiling "mt_abilities.sp" to include its content.
	#endif
public Plugin myinfo =
{
	name = "[MT] Drop Ability",
	author = MT_AUTHOR,
	description = "The Mutant Tank drops weapons upon death.",
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
			strcopy(error, err_max, "\"[MT] Drop Ability\" only supports Left 4 Dead 1 & 2.");

			return APLRes_SilentFailure;
		}
	}

	g_bDedicated = IsDedicatedServer();

	return APLRes_Success;
}
#else
	#if MT_DROP_COMPILE_METHOD == 1
		#error This file must be compiled as a standalone plugin.
	#endif
#endif

#define MT_DROP_SECTION "dropability"
#define MT_DROP_SECTION2 "drop ability"
#define MT_DROP_SECTION3 "drop_ability"
#define MT_DROP_SECTION4 "drop"

#define MT_MENU_DROP "Drop Ability"

char g_sMeleeScripts[][] =
{
	"scripts/melee/fireaxe.txt",
	"scripts/melee/baseball_bat.txt",
	"scripts/melee/cricket_bat.txt",
	"scripts/melee/crowbar.txt",
	"scripts/melee/golfclub.txt",
	"scripts/melee/electric_guitar.txt",
	"scripts/melee/katana.txt",
	"scripts/melee/knife.txt",
	"scripts/melee/machete.txt",
	"scripts/melee/frying_pan.txt",
	"scripts/melee/tonfa.txt",
	"scripts/melee/pitchfork.txt",
	"scripts/melee/shovel.txt"
}, g_sWeaponClasses[][] =
{
	"weapon_rifle",
	"weapon_autoshotgun",
	"weapon_hunting_rifle",
	"weapon_pumpshotgun",
	"weapon_smg",
	"weapon_pistol"
}, g_sWeaponModelsView[][] =
{
	"models/v_models/weapons/v_rifle_m16a2.mdl",
	"models/v_models/weapons/v_autoshot_m4super.mdl",
	"models/v_models/weapons/v_sniper_mini14.mdl",
	"models/v_models/weapons/v_shotgun.mdl",
	"models/v_models/weapons/v_smg_uzi.mdl",
	"models/v_models/weapons/v_pistol_1911.mdl"
}, g_sWeaponModelsWorld[][] =
{
	"models/w_models/weapons/w_rifle_m16a2.mdl",
	"models/w_models/weapons/w_autoshot_m4super.mdl",
	"models/w_models/weapons/w_sniper_mini14.mdl",
	"models/w_models/weapons/w_shotgun.mdl",
	"models/w_models/weapons/w_smg_uzi.mdl",
	"models/w_models/weapons/w_pistol_1911.mdl"
}, g_sWeaponClasses2[][] =
{
	"weapon_rifle_m60",
	"weapon_rifle_ak47",
	"weapon_rifle_desert",
	"weapon_rifle_sg552",
	"weapon_rifle",
	"weapon_shotgun_spas",
	"weapon_autoshotgun",
	"weapon_sniper_military",
	"weapon_sniper_awp",
	"weapon_sniper_scout",
	"weapon_hunting_rifle",
	"weapon_grenade_launcher",
	"weapon_shotgun_chrome",
	"weapon_pumpshotgun",
	"weapon_smg_silenced",
	"weapon_smg",
	"weapon_smg_mp5",
	"weapon_pistol_magnum",
	"weapon_pistol",
	"fireaxe",
	"baseball_bat",
	"weapon_chainsaw",
	"cricket_bat",
	"crowbar",
	"golfclub",
	"electric_guitar",
	"katana",
	"knife",
	"machete",
	"frying_pan",
	"tonfa",
	"pitchfork",
	"shovel"
}, g_sWeaponModelsView2[][] =
{
	"models/v_models/weapons/v_m60.mdl",
	"models/v_models/weapons/v_rifle_ak47.mdl",
	"models/v_models/weapons/v_desert_rifle.mdl",
	"models/v_models/weapons/v_rifle_sg552.mdl",
	"models/v_models/weapons/v_rifle_m16a2.mdl",
	"models/v_models/weapons/v_shotgun_spas.mdl",
	"models/v_models/weapons/v_autoshot_m4super.mdl",
	"models/v_models/weapons/v_sniper_military.mdl",
	"models/v_models/weapons/v_sniper_awp.mdl",
	"models/v_models/weapons/v_sniper_scout.mdl",
	"models/v_models/weapons/v_sniper_mini14.mdl",
	"models/v_models/weapons/v_grenade_launcher.mdl",
	"models/v_models/weapons/v_pumpshotgun_a.mdl",
	"models/v_models/weapons/v_shotgun.mdl",
	"models/v_models/weapons/v_smg_a.mdl",
	"models/v_models/weapons/v_smg_uzi.mdl",
	"models/v_models/weapons/v_smg_mp5.mdl",
	"models/v_models/weapons/v_desert_eagle.mdl",
	"models/v_models/weapons/v_pistol_a.mdl",
	"models/weapons/melee/v_fireaxe.mdl",
	"models/weapons/melee/v_bat.mdl",
	"models/weapons/melee/v_chainsaw.mdl",
	"models/weapons/melee/v_cricket_bat.mdl",
	"models/weapons/melee/v_crowbar.mdl",
	"models/weapons/melee/v_golfclub.mdl",
	"models/weapons/melee/v_electric_guitar.mdl",
	"models/weapons/melee/v_katana.mdl",
	"models/v_models/v_knife_t.mdl",
	"models/weapons/melee/v_machete.mdl",
	"models/weapons/melee/v_frying_pan.mdl",
	"models/weapons/melee/v_tonfa.mdl",
	"models/weapons/melee/v_pitchfork.mdl",
	"models/weapons/melee/v_shovel.mdl"
}, g_sWeaponModelsWorld2[][] =
{
	"models/w_models/weapons/w_m60.mdl",
	"models/w_models/weapons/w_rifle_ak47.mdl",
	"models/w_models/weapons/w_desert_rifle.mdl",
	"models/w_models/weapons/w_rifle_sg552.mdl",
	"models/w_models/weapons/w_rifle_m16a2.mdl",
	"models/w_models/weapons/w_shotgun_spas.mdl",
	"models/w_models/weapons/w_autoshot_m4super.mdl",
	"models/w_models/weapons/w_sniper_military.mdl",
	"models/w_models/weapons/w_sniper_awp.mdl",
	"models/w_models/weapons/w_sniper_scout.mdl",
	"models/w_models/weapons/w_sniper_mini14.mdl",
	"models/w_models/weapons/w_grenade_launcher.mdl",
	"models/w_models/weapons/w_pumpshotgun_a.mdl",
	"models/w_models/weapons/w_shotgun.mdl",
	"models/w_models/weapons/w_smg_a.mdl",
	"models/w_models/weapons/w_smg_uzi.mdl",
	"models/w_models/weapons/w_smg_mp5.mdl",
	"models/w_models/weapons/w_desert_eagle.mdl",
	"models/w_models/weapons/w_pistol_a.mdl",
	"models/weapons/melee/w_fireaxe.mdl",
	"models/weapons/melee/w_bat.mdl",
	"models/weapons/melee/w_chainsaw.mdl",
	"models/weapons/melee/w_cricket_bat.mdl",
	"models/weapons/melee/w_crowbar.mdl",
	"models/weapons/melee/w_golfclub.mdl",
	"models/weapons/melee/w_electric_guitar.mdl",
	"models/weapons/melee/w_katana.mdl",
	"models/w_models/weapons/w_knife_t.mdl",
	"models/weapons/melee/w_machete.mdl",
	"models/weapons/melee/w_frying_pan.mdl",
	"models/weapons/melee/w_tonfa.mdl",
	"models/weapons/melee/w_pitchfork.mdl",
	"models/weapons/melee/w_shovel.mdl"
};

enum struct esDropGeneral
{
	ConVar g_cvMTAssaultRifleAmmo;
	ConVar g_cvMTAutoShotgunAmmo;
	ConVar g_cvMTGrenadeLauncherAmmo;
	ConVar g_cvMTHuntingRifleAmmo;
	ConVar g_cvMTShotgunAmmo;
	ConVar g_cvMTSMGAmmo;
	ConVar g_cvMTSniperRifleAmmo;

	Handle g_hSDKGetMaxClip1;
}

esDropGeneral g_esDropGeneral;

enum struct esDropPlayer
{
	bool g_bActivated;

	char g_sDropWeaponName[32];

	float g_flCloseAreasOnly;
	float g_flDropChance;
	float g_flDropClipChance;
	float g_flDropWeaponScale;
	float g_flOpenAreasOnly;

	int g_iAccessFlags;
	int g_iComboAbility;
	int g_iDropAbility;
	int g_iDropMessage;
	int g_iDropHandPosition;
	int g_iDropMode;
	int g_iHumanAbility;
	int g_iRequiresHumans;
	int g_iTankType;
	int g_iWeapon;
	int g_iWeaponIndex;
}

esDropPlayer g_esDropPlayer[MAXPLAYERS + 1];

enum struct esDropAbility
{
	char g_sDropWeaponName[32];

	float g_flCloseAreasOnly;
	float g_flDropChance;
	float g_flDropClipChance;
	float g_flDropWeaponScale;
	float g_flOpenAreasOnly;

	int g_iAccessFlags;
	int g_iComboAbility;
	int g_iDropAbility;
	int g_iDropMessage;
	int g_iDropHandPosition;
	int g_iDropMode;
	int g_iHumanAbility;
	int g_iRequiresHumans;
}

esDropAbility g_esDropAbility[MT_MAXTYPES + 1];

enum struct esDropCache
{
	char g_sDropWeaponName[32];

	float g_flCloseAreasOnly;
	float g_flDropChance;
	float g_flDropClipChance;
	float g_flDropWeaponScale;
	float g_flOpenAreasOnly;

	int g_iComboAbility;
	int g_iDropAbility;
	int g_iDropMessage;
	int g_iDropHandPosition;
	int g_iDropMode;
	int g_iHumanAbility;
	int g_iRequiresHumans;
}

esDropCache g_esDropCache[MAXPLAYERS + 1];

#if defined MT_ABILITIES_MAIN
void vDropAllPluginsLoaded(GameData gdMutantTanks)
#else
public void OnAllPluginsLoaded()
#endif
{
#if !defined MT_ABILITIES_MAIN
	GameData gdMutantTanks = new GameData(MT_GAMEDATA);
	if (gdMutantTanks == null)
	{
		SetFailState("Unable to load the \"%s\" gamedata file.", MT_GAMEDATA);
	}
#endif
	int iOffset = gdMutantTanks.GetOffset("CBaseCombatWeapon::GetMaxClip1");
	if (iOffset == -1)
	{
#if defined MT_ABILITIES_MAIN
		delete gdMutantTanks;

		LogError("%s Failed to load offset: CBaseCombatWeapon::GetMaxClip1", MT_TAG);
#else
		SetFailState("Failed to load offset: CBaseCombatWeapon::GetMaxClip1");
#endif
	}

	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetVirtual(iOffset);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_ByValue);
	g_esDropGeneral.g_hSDKGetMaxClip1 = EndPrepSDKCall();
	if (g_esDropGeneral.g_hSDKGetMaxClip1 == null)
	{
#if defined MT_ABILITIES_MAIN
		LogError("%s Your \"CBaseCombatWeapon::GetMaxClip1\" offsets are outdated.", MT_TAG);
#else
		SetFailState("Your \"CBaseCombatWeapon::GetMaxClip1\" offsets are outdated.");
#endif
	}
#if !defined MT_ABILITIES_MAIN
	delete gdMutantTanks;
#endif
}

#if defined MT_ABILITIES_MAIN
void vDropPluginStart()
#else
public void OnPluginStart()
#endif
{
	g_esDropGeneral.g_cvMTAssaultRifleAmmo = FindConVar("ammo_assaultrifle_max");
	g_esDropGeneral.g_cvMTAutoShotgunAmmo = g_bSecondGame ? FindConVar("ammo_autoshotgun_max") : FindConVar("ammo_buckshot_max");
	g_esDropGeneral.g_cvMTGrenadeLauncherAmmo = FindConVar("ammo_grenadelauncher_max");
	g_esDropGeneral.g_cvMTHuntingRifleAmmo = FindConVar("ammo_huntingrifle_max");
	g_esDropGeneral.g_cvMTShotgunAmmo = g_bSecondGame ? FindConVar("ammo_shotgun_max") : FindConVar("ammo_buckshot_max");
	g_esDropGeneral.g_cvMTSMGAmmo = FindConVar("ammo_smg_max");
	g_esDropGeneral.g_cvMTSniperRifleAmmo = FindConVar("ammo_sniperrifle_max");
#if !defined MT_ABILITIES_MAIN
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");
	LoadTranslations("mutant_tanks_names.phrases");

	RegConsoleCmd("sm_mt_drop", cmdDropInfo, "View information about the Drop ability.");
#endif
}

#if defined MT_ABILITIES_MAIN
void vDropMapStart()
#else
public void OnMapStart()
#endif
{
	for (int iPos = 0; iPos < (sizeof g_sMeleeScripts); iPos++)
	{
		PrecacheGeneric(g_sMeleeScripts[iPos], true);
	}

	switch (g_bSecondGame)
	{
		case true:
		{
			for (int iPos = 0; iPos < (sizeof g_sWeaponModelsWorld2); iPos++)
			{
				PrecacheModel(g_sWeaponModelsView2[iPos], true);
				PrecacheModel(g_sWeaponModelsWorld2[iPos], true);
			}
		}
		case false:
		{
			for (int iPos = 0; iPos < (sizeof g_sWeaponModelsWorld); iPos++)
			{
				PrecacheModel(g_sWeaponModelsView[iPos], true);
				PrecacheModel(g_sWeaponModelsWorld[iPos], true);
			}
		}
	}

	vDropReset();
}

#if defined MT_ABILITIES_MAIN
void vDropClientPutInServer(int client)
#else
public void OnClientPutInServer(int client)
#endif
{
	vDropReset2(client);
}

#if defined MT_ABILITIES_MAIN
void vDropClientDisconnect_Post(int client)
#else
public void OnClientDisconnect_Post(int client)
#endif
{
	vDropReset2(client);
}

#if defined MT_ABILITIES_MAIN
void vDropMapEnd()
#else
public void OnMapEnd()
#endif
{
	vDropReset();
}

#if !defined MT_ABILITIES_MAIN
Action cmdDropInfo(int client, int args)
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
		case false: vDropMenu(client, MT_DROP_SECTION4, 0);
	}

	return Plugin_Handled;
}
#endif

void vDropMenu(int client, const char[] name, int item)
{
	if (StrContains(MT_DROP_SECTION4, name, false) == -1)
	{
		return;
	}

	Menu mAbilityMenu = new Menu(iDropMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Drop Ability Information");
	mAbilityMenu.AddItem("Status", "Status");
	mAbilityMenu.AddItem("Buttons", "Buttons");
	mAbilityMenu.AddItem("Details", "Details");
	mAbilityMenu.AddItem("Human Support", "Human Support");
	mAbilityMenu.DisplayAt(client, item, MENU_TIME_FOREVER);
}

int iDropMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esDropCache[param1].g_iDropAbility == 0) ? "AbilityStatus1" : "AbilityStatus2");
				case 1: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityButtons4");
				case 2: MT_PrintToChat(param1, "%s %t", MT_TAG3, "DropDetails");
				case 3: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esDropCache[param1].g_iHumanAbility == 0) ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME))
			{
				vDropMenu(param1, MT_DROP_SECTION4, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pDrop = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "DropMenu", param1);
			pDrop.SetTitle(sMenuTitle);
		}
		case MenuAction_DisplayItem:
		{
			if (param2 >= 0)
			{
				char sMenuOption[PLATFORM_MAX_PATH];

				switch (param2)
				{
					case 0: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "Status", param1);
					case 1: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "Buttons", param1);
					case 2: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "Details", param1);
					case 3: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "HumanSupport", param1);
				}

				return RedrawMenuItem(sMenuOption);
			}
		}
	}

	return 0;
}

#if defined MT_ABILITIES_MAIN
void vDropDisplayMenu(Menu menu)
#else
public void MT_OnDisplayMenu(Menu menu)
#endif
{
	menu.AddItem(MT_MENU_DROP, MT_MENU_DROP);
}

#if defined MT_ABILITIES_MAIN
void vDropMenuItemSelected(int client, const char[] info)
#else
public void MT_OnMenuItemSelected(int client, const char[] info)
#endif
{
	if (StrEqual(info, MT_MENU_DROP, false))
	{
		vDropMenu(client, MT_DROP_SECTION4, 0);
	}
}

#if defined MT_ABILITIES_MAIN
void vDropMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#else
public void MT_OnMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#endif
{
	if (StrEqual(info, MT_MENU_DROP, false))
	{
		FormatEx(buffer, size, "%T", "DropMenu2", client);
	}
}

#if defined MT_ABILITIES_MAIN
void vDropPluginCheck(ArrayList list)
#else
public void MT_OnPluginCheck(ArrayList list)
#endif
{
	list.PushString(MT_MENU_DROP);
}

#if defined MT_ABILITIES_MAIN
void vDropAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#else
public void MT_OnAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#endif
{
	list.PushString(MT_DROP_SECTION);
	list2.PushString(MT_DROP_SECTION2);
	list3.PushString(MT_DROP_SECTION3);
	list4.PushString(MT_DROP_SECTION4);
}

#if defined MT_ABILITIES_MAIN
void vDropCombineAbilities(int tank, int type, const float random, const char[] combo)
#else
public void MT_OnCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
#endif
{
	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esDropCache[tank].g_iHumanAbility != 2)
	{
		return;
	}

	char sCombo[320], sSet[4][32];
	FormatEx(sCombo, sizeof sCombo, ",%s,", combo);
	FormatEx(sSet[0], sizeof sSet[], ",%s,", MT_DROP_SECTION);
	FormatEx(sSet[1], sizeof sSet[], ",%s,", MT_DROP_SECTION2);
	FormatEx(sSet[2], sizeof sSet[], ",%s,", MT_DROP_SECTION3);
	FormatEx(sSet[3], sizeof sSet[], ",%s,", MT_DROP_SECTION4);
	if (StrContains(sCombo, sSet[0], false) != -1 || StrContains(sCombo, sSet[1], false) != -1 || StrContains(sCombo, sSet[2], false) != -1 || StrContains(sCombo, sSet[3], false) != -1)
	{
		if (type == MT_COMBO_UPONDEATH && g_esDropCache[tank].g_iDropAbility == 1 && g_esDropCache[tank].g_iComboAbility == 1 && g_esDropPlayer[tank].g_bActivated)
		{
			char sAbilities[320], sSubset[10][32];
			strcopy(sAbilities, sizeof sAbilities, combo);
			ExplodeString(sAbilities, ",", sSubset, sizeof sSubset, sizeof sSubset[]);

			float flDelay = 0.0;
			for (int iPos = 0; iPos < (sizeof sSubset); iPos++)
			{
				if (StrEqual(sSubset[iPos], MT_DROP_SECTION, false) || StrEqual(sSubset[iPos], MT_DROP_SECTION2, false) || StrEqual(sSubset[iPos], MT_DROP_SECTION3, false) || StrEqual(sSubset[iPos], MT_DROP_SECTION4, false))
				{
					flDelay = MT_GetCombinationSetting(tank, 4, iPos);

					switch (flDelay)
					{
						case 0.0: vDropWeapon(tank, 0, random, iPos);
						default:
						{
							DataPack dpCombo;
							CreateDataTimer(flDelay, tTimerDropCombo, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
							dpCombo.WriteCell(GetClientUserId(tank));
							dpCombo.WriteFloat(random);
							dpCombo.WriteCell(iPos);
						}
					}

					break;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vDropConfigsLoad(int mode)
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
				g_esDropAbility[iIndex].g_iAccessFlags = 0;
				g_esDropAbility[iIndex].g_flCloseAreasOnly = 0.0;
				g_esDropAbility[iIndex].g_iComboAbility = 0;
				g_esDropAbility[iIndex].g_iHumanAbility = 0;
				g_esDropAbility[iIndex].g_flOpenAreasOnly = 0.0;
				g_esDropAbility[iIndex].g_iRequiresHumans = 0;
				g_esDropAbility[iIndex].g_iDropAbility = 0;
				g_esDropAbility[iIndex].g_iDropMessage = 0;
				g_esDropAbility[iIndex].g_flDropChance = 33.3;
				g_esDropAbility[iIndex].g_flDropClipChance = 33.3;
				g_esDropAbility[iIndex].g_iDropHandPosition = 0;
				g_esDropAbility[iIndex].g_iDropMode = 0;
				g_esDropAbility[iIndex].g_sDropWeaponName[0] = '\0';
				g_esDropAbility[iIndex].g_flDropWeaponScale = 1.0;
			}
		}
		case 3:
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (bIsValidClient(iPlayer))
				{
					g_esDropPlayer[iPlayer].g_iAccessFlags = 0;
					g_esDropPlayer[iPlayer].g_flCloseAreasOnly = 0.0;
					g_esDropPlayer[iPlayer].g_iComboAbility = 0;
					g_esDropPlayer[iPlayer].g_iHumanAbility = 0;
					g_esDropPlayer[iPlayer].g_flOpenAreasOnly = 0.0;
					g_esDropPlayer[iPlayer].g_iRequiresHumans = 0;
					g_esDropPlayer[iPlayer].g_iDropAbility = 0;
					g_esDropPlayer[iPlayer].g_iDropMessage = 0;
					g_esDropPlayer[iPlayer].g_flDropChance = 0.0;
					g_esDropPlayer[iPlayer].g_flDropClipChance = 0.0;
					g_esDropPlayer[iPlayer].g_iDropHandPosition = 0;
					g_esDropPlayer[iPlayer].g_iDropMode = 0;
					g_esDropPlayer[iPlayer].g_sDropWeaponName[0] = '\0';
					g_esDropPlayer[iPlayer].g_flDropWeaponScale = 0.0;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vDropConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#else
public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#endif
{
	if (mode == 3 && bIsValidClient(admin))
	{
		g_esDropPlayer[admin].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_DROP_SECTION, MT_DROP_SECTION2, MT_DROP_SECTION3, MT_DROP_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esDropPlayer[admin].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esDropPlayer[admin].g_iComboAbility = iGetKeyValue(subsection, MT_DROP_SECTION, MT_DROP_SECTION2, MT_DROP_SECTION3, MT_DROP_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esDropPlayer[admin].g_iComboAbility, value, 0, 1);
		g_esDropPlayer[admin].g_iHumanAbility = iGetKeyValue(subsection, MT_DROP_SECTION, MT_DROP_SECTION2, MT_DROP_SECTION3, MT_DROP_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esDropPlayer[admin].g_iHumanAbility, value, 0, 2);
		g_esDropPlayer[admin].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_DROP_SECTION, MT_DROP_SECTION2, MT_DROP_SECTION3, MT_DROP_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esDropPlayer[admin].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esDropPlayer[admin].g_iRequiresHumans = iGetKeyValue(subsection, MT_DROP_SECTION, MT_DROP_SECTION2, MT_DROP_SECTION3, MT_DROP_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esDropPlayer[admin].g_iRequiresHumans, value, 0, 32);
		g_esDropPlayer[admin].g_iDropAbility = iGetKeyValue(subsection, MT_DROP_SECTION, MT_DROP_SECTION2, MT_DROP_SECTION3, MT_DROP_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esDropPlayer[admin].g_iDropAbility, value, 0, 1);
		g_esDropPlayer[admin].g_iDropMessage = iGetKeyValue(subsection, MT_DROP_SECTION, MT_DROP_SECTION2, MT_DROP_SECTION3, MT_DROP_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esDropPlayer[admin].g_iDropMessage, value, 0, 1);
		g_esDropPlayer[admin].g_flDropChance = flGetKeyValue(subsection, MT_DROP_SECTION, MT_DROP_SECTION2, MT_DROP_SECTION3, MT_DROP_SECTION4, key, "DropChance", "Drop Chance", "Drop_Chance", "chance", g_esDropPlayer[admin].g_flDropChance, value, 0.0, 100.0);
		g_esDropPlayer[admin].g_flDropClipChance = flGetKeyValue(subsection, MT_DROP_SECTION, MT_DROP_SECTION2, MT_DROP_SECTION3, MT_DROP_SECTION4, key, "DropClipChance", "Drop Clip Chance", "Drop_Clip_Chance", "clipchance", g_esDropPlayer[admin].g_flDropClipChance, value, 0.0, 100.0);
		g_esDropPlayer[admin].g_iDropHandPosition = iGetKeyValue(subsection, MT_DROP_SECTION, MT_DROP_SECTION2, MT_DROP_SECTION3, MT_DROP_SECTION4, key, "DropHandPosition", "Drop Hand Position", "Drop_Hand_Position", "handpos", g_esDropPlayer[admin].g_iDropHandPosition, value, 0, 3);
		g_esDropPlayer[admin].g_iDropMode = iGetKeyValue(subsection, MT_DROP_SECTION, MT_DROP_SECTION2, MT_DROP_SECTION3, MT_DROP_SECTION4, key, "DropMode", "Drop Mode", "Drop_Mode", "mode", g_esDropPlayer[admin].g_iDropMode, value, 0, 2);
		g_esDropPlayer[admin].g_flDropWeaponScale = flGetKeyValue(subsection, MT_DROP_SECTION, MT_DROP_SECTION2, MT_DROP_SECTION3, MT_DROP_SECTION4, key, "DropWeaponScale", "Drop Weapon Scale", "Drop_Weapon_Scale", "weaponscale", g_esDropPlayer[admin].g_flDropWeaponScale, value, 0.1, 2.0);
		g_esDropPlayer[admin].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_DROP_SECTION, MT_DROP_SECTION2, MT_DROP_SECTION3, MT_DROP_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);

		vGetKeyValue(subsection, MT_DROP_SECTION, MT_DROP_SECTION2, MT_DROP_SECTION3, MT_DROP_SECTION4, key, "DropWeaponName", "Drop Weapon Name", "Drop_Weapon_Name", "weaponname", g_esDropPlayer[admin].g_sDropWeaponName, sizeof esDropPlayer::g_sDropWeaponName, value);
	}

	if (mode < 3 && type > 0)
	{
		g_esDropAbility[type].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_DROP_SECTION, MT_DROP_SECTION2, MT_DROP_SECTION3, MT_DROP_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esDropAbility[type].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esDropAbility[type].g_iComboAbility = iGetKeyValue(subsection, MT_DROP_SECTION, MT_DROP_SECTION2, MT_DROP_SECTION3, MT_DROP_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esDropAbility[type].g_iComboAbility, value, 0, 1);
		g_esDropAbility[type].g_iHumanAbility = iGetKeyValue(subsection, MT_DROP_SECTION, MT_DROP_SECTION2, MT_DROP_SECTION3, MT_DROP_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esDropAbility[type].g_iHumanAbility, value, 0, 2);
		g_esDropAbility[type].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_DROP_SECTION, MT_DROP_SECTION2, MT_DROP_SECTION3, MT_DROP_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esDropAbility[type].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esDropAbility[type].g_iRequiresHumans = iGetKeyValue(subsection, MT_DROP_SECTION, MT_DROP_SECTION2, MT_DROP_SECTION3, MT_DROP_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esDropAbility[type].g_iRequiresHumans, value, 0, 32);
		g_esDropAbility[type].g_iDropAbility = iGetKeyValue(subsection, MT_DROP_SECTION, MT_DROP_SECTION2, MT_DROP_SECTION3, MT_DROP_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esDropAbility[type].g_iDropAbility, value, 0, 1);
		g_esDropAbility[type].g_iDropMessage = iGetKeyValue(subsection, MT_DROP_SECTION, MT_DROP_SECTION2, MT_DROP_SECTION3, MT_DROP_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esDropAbility[type].g_iDropMessage, value, 0, 1);
		g_esDropAbility[type].g_flDropChance = flGetKeyValue(subsection, MT_DROP_SECTION, MT_DROP_SECTION2, MT_DROP_SECTION3, MT_DROP_SECTION4, key, "DropChance", "Drop Chance", "Drop_Chance", "chance", g_esDropAbility[type].g_flDropChance, value, 0.0, 100.0);
		g_esDropAbility[type].g_flDropClipChance = flGetKeyValue(subsection, MT_DROP_SECTION, MT_DROP_SECTION2, MT_DROP_SECTION3, MT_DROP_SECTION4, key, "DropClipChance", "Drop Clip Chance", "Drop_Clip_Chance", "clipchance", g_esDropAbility[type].g_flDropClipChance, value, 0.0, 100.0);
		g_esDropAbility[type].g_iDropHandPosition = iGetKeyValue(subsection, MT_DROP_SECTION, MT_DROP_SECTION2, MT_DROP_SECTION3, MT_DROP_SECTION4, key, "DropHandPosition", "Drop Hand Position", "Drop_Hand_Position", "handpos", g_esDropAbility[type].g_iDropHandPosition, value, 0, 3);
		g_esDropAbility[type].g_iDropMode = iGetKeyValue(subsection, MT_DROP_SECTION, MT_DROP_SECTION2, MT_DROP_SECTION3, MT_DROP_SECTION4, key, "DropMode", "Drop Mode", "Drop_Mode", "mode", g_esDropAbility[type].g_iDropMode, value, 0, 2);
		g_esDropAbility[type].g_flDropWeaponScale = flGetKeyValue(subsection, MT_DROP_SECTION, MT_DROP_SECTION2, MT_DROP_SECTION3, MT_DROP_SECTION4, key, "DropWeaponScale", "Drop Weapon Scale", "Drop_Weapon_Scale", "weaponscale", g_esDropAbility[type].g_flDropWeaponScale, value, 0.1, 2.0);
		g_esDropAbility[type].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_DROP_SECTION, MT_DROP_SECTION2, MT_DROP_SECTION3, MT_DROP_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);

		vGetKeyValue(subsection, MT_DROP_SECTION, MT_DROP_SECTION2, MT_DROP_SECTION3, MT_DROP_SECTION4, key, "DropWeaponName", "Drop Weapon Name", "Drop_Weapon_Name", "weaponname", g_esDropAbility[type].g_sDropWeaponName, sizeof esDropAbility::g_sDropWeaponName, value);
	}
}

#if defined MT_ABILITIES_MAIN
void vDropSettingsCached(int tank, bool apply, int type)
#else
public void MT_OnSettingsCached(int tank, bool apply, int type)
#endif
{
	bool bHuman = bIsTank(tank, MT_CHECK_FAKECLIENT);
	g_esDropCache[tank].g_flCloseAreasOnly = flGetSettingValue(apply, bHuman, g_esDropPlayer[tank].g_flCloseAreasOnly, g_esDropAbility[type].g_flCloseAreasOnly);
	g_esDropCache[tank].g_iComboAbility = iGetSettingValue(apply, bHuman, g_esDropPlayer[tank].g_iComboAbility, g_esDropAbility[type].g_iComboAbility);
	g_esDropCache[tank].g_flDropChance = flGetSettingValue(apply, bHuman, g_esDropPlayer[tank].g_flDropChance, g_esDropAbility[type].g_flDropChance);
	g_esDropCache[tank].g_flDropClipChance = flGetSettingValue(apply, bHuman, g_esDropPlayer[tank].g_flDropClipChance, g_esDropAbility[type].g_flDropClipChance);
	g_esDropCache[tank].g_flDropWeaponScale = flGetSettingValue(apply, bHuman, g_esDropPlayer[tank].g_flDropWeaponScale, g_esDropAbility[type].g_flDropWeaponScale);
	g_esDropCache[tank].g_iDropAbility = iGetSettingValue(apply, bHuman, g_esDropPlayer[tank].g_iDropAbility, g_esDropAbility[type].g_iDropAbility);
	g_esDropCache[tank].g_iDropMessage = iGetSettingValue(apply, bHuman, g_esDropPlayer[tank].g_iDropMessage, g_esDropAbility[type].g_iDropMessage);
	g_esDropCache[tank].g_iDropHandPosition = iGetSettingValue(apply, bHuman, g_esDropPlayer[tank].g_iDropHandPosition, g_esDropAbility[type].g_iDropHandPosition);
	g_esDropCache[tank].g_iDropMode = iGetSettingValue(apply, bHuman, g_esDropPlayer[tank].g_iDropMode, g_esDropAbility[type].g_iDropMode);
	g_esDropCache[tank].g_iHumanAbility = iGetSettingValue(apply, bHuman, g_esDropPlayer[tank].g_iHumanAbility, g_esDropAbility[type].g_iHumanAbility);
	g_esDropCache[tank].g_flOpenAreasOnly = flGetSettingValue(apply, bHuman, g_esDropPlayer[tank].g_flOpenAreasOnly, g_esDropAbility[type].g_flOpenAreasOnly);
	g_esDropCache[tank].g_iRequiresHumans = iGetSettingValue(apply, bHuman, g_esDropPlayer[tank].g_iRequiresHumans, g_esDropAbility[type].g_iRequiresHumans);
	g_esDropPlayer[tank].g_iTankType = apply ? type : 0;

	vGetSettingValue(apply, bHuman, g_esDropCache[tank].g_sDropWeaponName, sizeof esDropCache::g_sDropWeaponName, g_esDropPlayer[tank].g_sDropWeaponName, g_esDropAbility[type].g_sDropWeaponName);
}

#if defined MT_ABILITIES_MAIN
void vDropCopyStats(int oldTank, int newTank)
#else
public void MT_OnCopyStats(int oldTank, int newTank)
#endif
{
	vDropCopyStats2(oldTank, newTank);

	if (oldTank != newTank)
	{
		vRemoveDrop(oldTank);
	}
}

#if !defined MT_ABILITIES_MAIN
public void MT_OnPluginUpdate()
{
	MT_ReloadPlugin(null);
}
#endif

#if defined MT_ABILITIES_MAIN
void vDropEventFired(Event event, const char[] name)
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
			vDropCopyStats2(iBot, iTank);
			vRemoveDrop(iBot);
		}
	}
	else if (StrEqual(name, "player_bot_replace"))
	{
		int iTankId = event.GetInt("player"), iTank = GetClientOfUserId(iTankId),
			iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId);
		if (bIsValidClient(iTank) && bIsTank(iBot))
		{
			vDropCopyStats2(iTank, iBot);
			vRemoveDrop(iTank);
		}
	}
	else if (StrEqual(name, "player_death"))
	{
		int iTankId = event.GetInt("userid"), iTank = GetClientOfUserId(iTankId);
		if (MT_IsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME) && MT_IsCustomTankSupported(iTank) && g_esDropPlayer[iTank].g_bActivated)
		{
			if (MT_HasAdminAccess(iTank) || bHasAdminAccess(iTank, g_esDropAbility[g_esDropPlayer[iTank].g_iTankType].g_iAccessFlags, g_esDropPlayer[iTank].g_iAccessFlags))
			{
				vDropWeapon(iTank, 1, MT_GetRandomFloat(0.1, 100.0));
			}

			vDropReset2(iTank);
		}
	}
	else if (StrEqual(name, "mission_lost") || StrEqual(name, "round_start") || StrEqual(name, "round_end"))
	{
		vDropReset();
	}
}

#if defined MT_ABILITIES_MAIN
void vDropAbilityActivated(int tank)
#else
public void MT_OnAbilityActivated(int tank)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esDropAbility[g_esDropPlayer[tank].g_iTankType].g_iAccessFlags, g_esDropPlayer[tank].g_iAccessFlags)) || g_esDropCache[tank].g_iHumanAbility == 0))
	{
		return;
	}

	if (MT_IsTankSupported(tank) && (!bIsTank(tank, MT_CHECK_FAKECLIENT) || g_esDropCache[tank].g_iHumanAbility != 1) && MT_IsCustomTankSupported(tank) && g_esDropCache[tank].g_iDropAbility == 1 && !g_esDropPlayer[tank].g_bActivated)
	{
		RequestFrame(vDropFrame, GetClientUserId(tank));
	}
}

#if defined MT_ABILITIES_MAIN
void vDropButtonPressed(int tank, int button)
#else
public void MT_OnButtonPressed(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && MT_IsCustomTankSupported(tank))
	{
		if (bIsAreaNarrow(tank, g_esDropCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esDropCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esDropPlayer[tank].g_iTankType) || (g_esDropCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esDropCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esDropAbility[g_esDropPlayer[tank].g_iTankType].g_iAccessFlags, g_esDropPlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		if ((button & MT_SPECIAL_KEY2) && g_esDropCache[tank].g_iDropAbility == 1 && g_esDropCache[tank].g_iHumanAbility == 1)
		{
			switch (g_esDropPlayer[tank].g_bActivated)
			{
				case true: MT_PrintToChat(tank, "%s %t", MT_TAG3, "DropHuman2");
				case false:
				{
					RequestFrame(vDropFrame, GetClientUserId(tank));

					MT_PrintToChat(tank, "%s %t", MT_TAG3, "DropHuman");
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vDropChangeType(int tank, int oldType)
#else
public void MT_OnChangeType(int tank, int oldType, int newType, bool revert)
#endif
{
	if (oldType <= 0)
	{
		return;
	}

	vDropWeapon(tank, 1, MT_GetRandomFloat(0.1, 100.0));
}

void vDropWeapon(int tank, int value, float random, int pos = -1)
{
	float flChance = (pos != -1) ? MT_GetCombinationSetting(tank, 1, pos) : g_esDropCache[tank].g_flDropChance;
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME) && MT_IsCustomTankSupported(tank) && g_esDropCache[tank].g_iDropAbility == 1 && random <= flChance && bIsValidEntRef(g_esDropPlayer[tank].g_iWeapon))
	{
		if (g_esDropCache[tank].g_iComboAbility == value || bIsAreaNarrow(tank, g_esDropCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esDropCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esDropPlayer[tank].g_iTankType) || (g_esDropCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esDropCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esDropAbility[g_esDropPlayer[tank].g_iTankType].g_iAccessFlags, g_esDropPlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		char sWeapon[32];
		strcopy(sWeapon, sizeof sWeapon, (g_bSecondGame ? g_sWeaponClasses2[g_esDropPlayer[tank].g_iWeaponIndex] : g_sWeaponClasses[g_esDropPlayer[tank].g_iWeaponIndex]));

		float flPos[3], flAngles[3];
		GetClientEyePosition(tank, flPos);
		GetClientAbsAngles(tank, flAngles);

		if (g_esDropCache[tank].g_iDropMode != 2 && strncmp(sWeapon, "weapon", 6) != -1)
		{
			int iDrop = CreateEntityByName(sWeapon);
			if (bIsValidEntity(iDrop))
			{
				TeleportEntity(iDrop, flPos, flAngles);
				DispatchSpawn(iDrop);

				int iAmmo = 0, iClip = 0, iType = GetEntProp(iDrop, Prop_Send, "m_iPrimaryAmmoType");

				if (g_bSecondGame)
				{
					switch (iType)
					{
						case 3: iAmmo = g_esDropGeneral.g_cvMTAssaultRifleAmmo.IntValue; // rifle/rifle_ak47/rifle_desert/rifle_sg552
						case 5: iAmmo = g_esDropGeneral.g_cvMTSMGAmmo.IntValue; // smg/smg_silenced/smg_mp5
						case 7: iAmmo = g_esDropGeneral.g_cvMTShotgunAmmo.IntValue; // pumpshotgun/shotgun_chrome
						case 8: iAmmo = g_esDropGeneral.g_cvMTAutoShotgunAmmo.IntValue; // autoshotgun/shotgun_spas
						case 9: iAmmo = g_esDropGeneral.g_cvMTHuntingRifleAmmo.IntValue; // hunting_rifle
						case 10: iAmmo = g_esDropGeneral.g_cvMTSniperRifleAmmo.IntValue; // sniper_military/sniper_awp/sniper_scout
						case 17: iAmmo = g_esDropGeneral.g_cvMTGrenadeLauncherAmmo.IntValue; // grenade_launcher
					}
				}
				else
				{
					switch (iType)
					{
						case 2: iAmmo = g_esDropGeneral.g_cvMTHuntingRifleAmmo.IntValue; // hunting_rifle
						case 3: iAmmo = g_esDropGeneral.g_cvMTAssaultRifleAmmo.IntValue; // rifle
						case 5: iAmmo = g_esDropGeneral.g_cvMTSMGAmmo.IntValue; // smg
						case 6: iAmmo = g_esDropGeneral.g_cvMTShotgunAmmo.IntValue; // pumpshotgun/autoshotgun
					}
				}

				if (MT_GetRandomFloat(0.1, 100.0) <= g_esDropCache[tank].g_flDropClipChance)
				{
					iClip = SDKCall(g_esDropGeneral.g_hSDKGetMaxClip1, iDrop);
				}

				if (iClip > 0)
				{
					SetEntProp(iDrop, Prop_Send, "m_iClip1", iClip);
				}

				if (iAmmo > 0)
				{
					SetEntProp(iDrop, Prop_Send, "m_iExtraPrimaryAmmo", iAmmo);
				}

				if (g_esDropCache[tank].g_iDropMessage == 1)
				{
					char sTankName[33];
					MT_GetTankName(tank, sTankName);
					MT_PrintToChatAll("%s %t", MT_TAG2, "Drop", sTankName);
					MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Drop", LANG_SERVER, sTankName);
				}
			}
		}
		else if (g_esDropCache[tank].g_iDropMode != 1 && g_bSecondGame)
		{
			int iDrop = CreateEntityByName("weapon_melee");
			if (bIsValidEntity(iDrop))
			{
				DispatchKeyValue(iDrop, "melee_script_name", sWeapon);
				TeleportEntity(iDrop, flPos, flAngles);
				DispatchSpawn(iDrop);

				if (g_esDropCache[tank].g_iDropMessage == 1)
				{
					char sTankName[33];
					MT_GetTankName(tank, sTankName);
					MT_PrintToChatAll("%s %t", MT_TAG2, "Drop2", sTankName);
					MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Drop2", LANG_SERVER, sTankName);
				}
			}
		}
	}

	vRemoveDrop(tank);
}

void vDropCopyStats2(int oldTank, int newTank)
{
	g_esDropPlayer[newTank].g_bActivated = g_esDropPlayer[oldTank].g_bActivated;
	g_esDropPlayer[newTank].g_iWeapon = g_esDropPlayer[oldTank].g_iWeapon;
	g_esDropPlayer[newTank].g_iWeaponIndex = g_esDropPlayer[oldTank].g_iWeaponIndex;
}

void vRemoveDrop(int tank)
{
	if (bIsValidEntRef(g_esDropPlayer[tank].g_iWeapon))
	{
		g_esDropPlayer[tank].g_iWeapon = EntRefToEntIndex(g_esDropPlayer[tank].g_iWeapon);
		if (bIsValidEntity(g_esDropPlayer[tank].g_iWeapon))
		{
			MT_HideEntity(g_esDropPlayer[tank].g_iWeapon, false);
			RemoveEntity(g_esDropPlayer[tank].g_iWeapon);
		}
	}

	vDropReset2(tank);
}

void vDropReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
		{
			vRemoveDrop(iPlayer);
			vDropReset2(iPlayer);
		}
	}
}

void vDropReset2(int tank)
{
	g_esDropPlayer[tank].g_bActivated = false;
	g_esDropPlayer[tank].g_iWeapon = INVALID_ENT_REFERENCE;
	g_esDropPlayer[tank].g_iWeaponIndex = 0;
}

int iGetNamedWeapon(int tank)
{
	if (g_esDropCache[tank].g_sDropWeaponName[0] == '\0')
	{
		return -1;
	}

	char sName[32];
	int iSize = g_bSecondGame ? (sizeof g_sWeaponClasses2) : (sizeof g_sWeaponClasses);
	for (int iPos = 0; iPos < iSize; iPos++)
	{
		strcopy(sName, sizeof sName, (g_bSecondGame ? g_sWeaponClasses2[iPos] : g_sWeaponClasses[iPos]));
		if (StrEqual(sName, g_esDropCache[tank].g_sDropWeaponName, false) || (!strncmp(sName, "weapon_", 7) && StrEqual(sName[7], g_esDropCache[tank].g_sDropWeaponName, false)))
		{
			return iPos;
		}
	}

	return -1;
}

int iGetRandomWeapon(int tank)
{
	int iDropValue = 0;

	switch (g_esDropCache[tank].g_iDropMode)
	{
		case 0: iDropValue = MT_GetRandomInt(0, 32);
		case 1: iDropValue = MT_GetRandomInt(0, 18);
		case 2: iDropValue = MT_GetRandomInt(19, 32);
	}

	return g_bSecondGame ? iDropValue : MT_GetRandomInt(0, 5);
}

void vDropFrame(int userid)
{
	int iTank = GetClientOfUserId(userid);
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || bIsAreaNarrow(iTank, g_esDropCache[iTank].g_flOpenAreasOnly) || bIsAreaWide(iTank, g_esDropCache[iTank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esDropPlayer[iTank].g_iTankType) || (g_esDropCache[iTank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esDropCache[iTank].g_iRequiresHumans) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esDropAbility[g_esDropPlayer[iTank].g_iTankType].g_iAccessFlags, g_esDropPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esDropPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esDropCache[iTank].g_iDropAbility == 0 || g_esDropPlayer[iTank].g_bActivated)
	{
		g_esDropPlayer[iTank].g_bActivated = false;

		return;
	}

	vRemoveDrop(iTank);

	int iPosition = (0 < g_esDropCache[iTank].g_iDropHandPosition < 3) ? g_esDropCache[iTank].g_iDropHandPosition : MT_GetRandomInt(1, 2),
		iWeapon = iGetNamedWeapon(iTank);
	if (iWeapon == -1)
	{
		iWeapon = iGetRandomWeapon(iTank);
	}

	g_esDropPlayer[iTank].g_iWeapon = CreateEntityByName("prop_dynamic_override");
	if (bIsValidEntity(g_esDropPlayer[iTank].g_iWeapon))
	{
		SetEntityModel(g_esDropPlayer[iTank].g_iWeapon, (g_bSecondGame ? g_sWeaponModelsWorld2[iWeapon] : g_sWeaponModelsWorld[iWeapon]));
		vSetEntityParent(g_esDropPlayer[iTank].g_iWeapon, iTank, true);

		char sPosition[32];

		switch (iPosition)
		{
			case 1: sPosition = "rhand";
			case 2: sPosition = "lhand";
		}

		SetVariantString(sPosition);
		AcceptEntityInput(g_esDropPlayer[iTank].g_iWeapon, "SetParentAttachment");

		float flPos[3], flAngles[3], flScale;

		switch (g_bSecondGame)
		{
			case true:
			{
				if (iWeapon == 21)
				{
					switch (iPosition)
					{
						case 1:
						{
							vSetVector(flPos, -23.0, -30.0, -5.0);
							vSetVector(flAngles, 0.0, 60.0, 180.0);
						}
						case 2:
						{
							vSetVector(flPos, -9.0, -32.0, -1.0);
							vSetVector(flAngles, 0.0, 60.0, 180.0);
						}
					}
				}
				else if (0 <= iWeapon <= 13)
				{
					switch (iPosition)
					{
						case 1:
						{
							vSetVector(flPos, 1.0, -5.0, 3.0);
							vSetVector(flAngles, 0.0, -90.0, 90.0);
						}
						case 2:
						{
							vSetVector(flPos, 4.0, -5.0, -3.0);
							vSetVector(flAngles, 0.0, -90.0, 90.0);
						}
					}
				}
				else
				{
					switch (iPosition)
					{
						case 1:
						{
							vSetVector(flPos, -4.0, 0.0, 3.0);
							vSetVector(flAngles, 0.0, -11.0, 100.0);
						}
						case 2:
						{
							vSetVector(flPos, 4.0, 0.0, -3.0);
							vSetVector(flAngles, 0.0, -11.0, 100.0);
						}
					}
				}

				flScale = (g_esDropCache[iTank].g_flDropWeaponScale * 1.5);
			}
			case false:
			{
				if (0 <= iWeapon <= 3)
				{
					switch (iPosition)
					{
						case 1:
						{
							vSetVector(flPos, 1.0, -5.0, 3.0);
							vSetVector(flAngles, 0.0, -90.0, 90.0);
						}
						case 2:
						{
							vSetVector(flPos, 4.0, -5.0, -3.0);
							vSetVector(flAngles, 0.0, -90.0, 90.0);
						}
					}
				}
				else
				{
					switch (iPosition)
					{
						case 1:
						{
							vSetVector(flPos, -4.0, 0.0, 3.0);
							vSetVector(flAngles, 0.0, -11.0, 100.0);
						}
						case 2:
						{
							vSetVector(flPos, 4.0, 0.0, -3.0);
							vSetVector(flAngles, 0.0, -11.0, 100.0);
						}
					}
				}
			}
		}

		SetEntProp(g_esDropPlayer[iTank].g_iWeapon, Prop_Send, "m_CollisionGroup", 2);
		TeleportEntity(g_esDropPlayer[iTank].g_iWeapon, flPos, flAngles);
		DispatchSpawn(g_esDropPlayer[iTank].g_iWeapon);

		if (g_bSecondGame)
		{
			SetEntPropFloat(g_esDropPlayer[iTank].g_iWeapon, Prop_Send, "m_flModelScale", flScale);
		}

		g_esDropPlayer[iTank].g_bActivated = true;
		g_esDropPlayer[iTank].g_iWeaponIndex = iWeapon;
		MT_HideEntity(g_esDropPlayer[iTank].g_iWeapon, true);
		g_esDropPlayer[iTank].g_iWeapon = EntIndexToEntRef(g_esDropPlayer[iTank].g_iWeapon);

		DataPack dpRender;
		CreateDataTimer(0.1, tTimerDropRenderWeapon, dpRender, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
		dpRender.WriteCell(g_esDropPlayer[iTank].g_iWeapon);
		dpRender.WriteCell(GetClientUserId(iTank));
	}
}

Action tTimerDropCombo(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esDropAbility[g_esDropPlayer[iTank].g_iTankType].g_iAccessFlags, g_esDropPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esDropPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esDropCache[iTank].g_iDropAbility == 0 || g_esDropPlayer[iTank].g_bActivated)
	{
		return Plugin_Stop;
	}

	float flRandom = pack.ReadFloat();
	int iPos = pack.ReadCell();
	vDropWeapon(iTank, 0, flRandom, iPos);

	return Plugin_Continue;
}

Action tTimerDropRenderWeapon(Handle timer, DataPack pack)
{
	pack.Reset();

	int iWeapon = EntRefToEntIndex(pack.ReadCell()), iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || iWeapon == INVALID_ENT_REFERENCE || !bIsValidEntity(iWeapon) || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esDropAbility[g_esDropPlayer[iTank].g_iTankType].g_iAccessFlags, g_esDropPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esDropPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esDropCache[iTank].g_iDropAbility == 0 || !g_esDropPlayer[iTank].g_bActivated)
	{
		return Plugin_Stop;
	}

	int iAlpha = GetEntData(iTank, (GetEntSendPropOffs(iTank, "m_clrRender") + 3), 1);
	SetEntityRenderMode(iWeapon, GetEntityRenderMode(iTank));
	SetEntData(iWeapon, (GetEntSendPropOffs(iWeapon, "m_clrRender") + 3), iAlpha, 1, true);

	return Plugin_Continue;
}