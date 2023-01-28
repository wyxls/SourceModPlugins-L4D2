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

#define MT_SMITE_COMPILE_METHOD 0 // 0: packaged, 1: standalone

#if !defined MT_ABILITIES_MAIN2
	#if MT_SMITE_COMPILE_METHOD == 1
		#include <sourcemod>
		#include <mutant_tanks>
	#else
		#error This file must be inside "scripting/mutant_tanks/abilities2" while compiling "mt_abilities2.sp" to include its content.
	#endif
public Plugin myinfo =
{
	name = "[MT] Smite Ability",
	author = MT_AUTHOR,
	description = "The Mutant Tank smites survivors.",
	version = MT_VERSION,
	url = MT_URL
};

bool g_bDedicated, g_bLateLoad;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion evEngine = GetEngineVersion();
	if (evEngine != Engine_Left4Dead && evEngine != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "\"[MT] Smite Ability\" only supports Left 4 Dead 1 & 2.");

		return APLRes_SilentFailure;
	}

	g_bDedicated = IsDedicatedServer();
	g_bLateLoad = late;

	return APLRes_Success;
}
#else
	#if MT_SMITE_COMPILE_METHOD == 1
		#error This file must be compiled as a standalone plugin.
	#endif
#endif

#define SOUND_EXPLOSION "ambient/explosions/explode_2.wav"

#define SPRITE_GLOW "sprites/glow01.vmt"

#define MT_SMITE_SECTION "smiteability"
#define MT_SMITE_SECTION2 "smite ability"
#define MT_SMITE_SECTION3 "smite_ability"
#define MT_SMITE_SECTION4 "smite"

#define MT_MENU_SMITE "Smite Ability"

enum struct esSmitePlayer
{
	bool g_bFailed;
	bool g_bNoAmmo;

	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flSmiteChance;
	float g_flSmiteRange;
	float g_flSmiteRangeChance;

	int g_iAccessFlags;
	int g_iAmmoCount;
	int g_iComboAbility;
	int g_iCooldown;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iImmunityFlags;
	int g_iRangeCooldown;
	int g_iRequiresHumans;
	int g_iSmiteAbility;
	int g_iSmiteBody;
	int g_iSmiteCooldown;
	int g_iSmiteEffect;
	int g_iSmiteHit;
	int g_iSmiteHitMode;
	int g_iSmiteMessage;
	int g_iSmiteRangeCooldown;
	int g_iTankType;
}

esSmitePlayer g_esSmitePlayer[MAXPLAYERS + 1];

enum struct esSmiteAbility
{
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flSmiteChance;
	float g_flSmiteRange;
	float g_flSmiteRangeChance;

	int g_iAccessFlags;
	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iImmunityFlags;
	int g_iRequiresHumans;
	int g_iSmiteAbility;
	int g_iSmiteBody;
	int g_iSmiteCooldown;
	int g_iSmiteEffect;
	int g_iSmiteHit;
	int g_iSmiteHitMode;
	int g_iSmiteMessage;
	int g_iSmiteRangeCooldown;
}

esSmiteAbility g_esSmiteAbility[MT_MAXTYPES + 1];

enum struct esSmiteCache
{
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flSmiteChance;
	float g_flSmiteRange;
	float g_flSmiteRangeChance;

	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iRequiresHumans;
	int g_iSmiteAbility;
	int g_iSmiteBody;
	int g_iSmiteCooldown;
	int g_iSmiteEffect;
	int g_iSmiteHit;
	int g_iSmiteHitMode;
	int g_iSmiteMessage;
	int g_iSmiteRangeCooldown;
}

esSmiteCache g_esSmiteCache[MAXPLAYERS + 1];

int g_iSmiteDeathModelOwner = 0, g_iSmiteSprite = -1;

#if !defined MT_ABILITIES_MAIN2
public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");
	LoadTranslations("mutant_tanks_names.phrases");

	RegConsoleCmd("sm_mt_smite", cmdSmiteInfo, "View information about the Smite ability.");

	if (g_bLateLoad)
	{
		for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
		{
			if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
			{
				OnClientPutInServer(iPlayer);
			}
		}

		g_bLateLoad = false;
	}
}
#endif

#if defined MT_ABILITIES_MAIN2
void vSmiteMapStart()
#else
public void OnMapStart()
#endif
{
	g_iSmiteSprite = PrecacheModel(SPRITE_GLOW, true);
	PrecacheSound(SOUND_EXPLOSION, true);

	vSmiteReset();
}

#if defined MT_ABILITIES_MAIN2
void vSmiteClientPutInServer(int client)
#else
public void OnClientPutInServer(int client)
#endif
{
	SDKHook(client, SDKHook_OnTakeDamage, OnSmiteTakeDamage);
	vRemoveSmite(client);
}

#if defined MT_ABILITIES_MAIN2
void vSmiteClientDisconnect_Post(int client)
#else
public void OnClientDisconnect_Post(int client)
#endif
{
	vRemoveSmite(client);
}

#if defined MT_ABILITIES_MAIN2
void vSmiteMapEnd()
#else
public void OnMapEnd()
#endif
{
	vSmiteReset();
}

#if !defined MT_ABILITIES_MAIN2
Action cmdSmiteInfo(int client, int args)
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
		case false: vSmiteMenu(client, MT_SMITE_SECTION4, 0);
	}

	return Plugin_Handled;
}
#endif

void vSmiteMenu(int client, const char[] name, int item)
{
	if (StrContains(MT_SMITE_SECTION4, name, false) == -1)
	{
		return;
	}

	Menu mAbilityMenu = new Menu(iSmiteMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Smite Ability Information");
	mAbilityMenu.AddItem("Status", "Status");
	mAbilityMenu.AddItem("Ammunition", "Ammunition");
	mAbilityMenu.AddItem("Buttons", "Buttons");
	mAbilityMenu.AddItem("Cooldown", "Cooldown");
	mAbilityMenu.AddItem("Details", "Details");
	mAbilityMenu.AddItem("Human Support", "Human Support");
	mAbilityMenu.AddItem("Range Cooldown", "Range Cooldown");
	mAbilityMenu.DisplayAt(client, item, MENU_TIME_FOREVER);
}

int iSmiteMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esSmiteCache[param1].g_iSmiteAbility == 0) ? "AbilityStatus1" : "AbilityStatus2");
				case 1: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityAmmo", (g_esSmiteCache[param1].g_iHumanAmmo - g_esSmitePlayer[param1].g_iAmmoCount), g_esSmiteCache[param1].g_iHumanAmmo);
				case 2: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityButtons2");
				case 3: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityCooldown", ((g_esSmiteCache[param1].g_iHumanAbility == 1) ? g_esSmiteCache[param1].g_iHumanCooldown : g_esSmiteCache[param1].g_iSmiteCooldown));
				case 4: MT_PrintToChat(param1, "%s %t", MT_TAG3, "SmiteDetails");
				case 5: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esSmiteCache[param1].g_iHumanAbility == 0) ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
				case 6: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityRangeCooldown", ((g_esSmiteCache[param1].g_iHumanAbility == 1) ? g_esSmiteCache[param1].g_iHumanRangeCooldown : g_esSmiteCache[param1].g_iSmiteRangeCooldown));
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME))
			{
				vSmiteMenu(param1, MT_SMITE_SECTION4, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pSmite = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "SmiteMenu", param1);
			pSmite.SetTitle(sMenuTitle);
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
					case 3: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "Cooldown", param1);
					case 4: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "Details", param1);
					case 5: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "HumanSupport", param1);
					case 6: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "RangeCooldown", param1);
				}

				return RedrawMenuItem(sMenuOption);
			}
		}
	}

	return 0;
}

#if defined MT_ABILITIES_MAIN2
void vSmiteDisplayMenu(Menu menu)
#else
public void MT_OnDisplayMenu(Menu menu)
#endif
{
	menu.AddItem(MT_MENU_SMITE, MT_MENU_SMITE);
}

#if defined MT_ABILITIES_MAIN2
void vSmiteMenuItemSelected(int client, const char[] info)
#else
public void MT_OnMenuItemSelected(int client, const char[] info)
#endif
{
	if (StrEqual(info, MT_MENU_SMITE, false))
	{
		vSmiteMenu(client, MT_SMITE_SECTION4, 0);
	}
}

#if defined MT_ABILITIES_MAIN2
void vSmiteMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#else
public void MT_OnMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#endif
{
	if (StrEqual(info, MT_MENU_SMITE, false))
	{
		FormatEx(buffer, size, "%T", "SmiteMenu2", client);
	}
}

#if defined MT_ABILITIES_MAIN2
void vSmiteEntityCreated(int entity, const char[] classname)
#else
public void OnEntityCreated(int entity, const char[] classname)
#endif
{
	if (bIsValidEntity(entity) && StrEqual(classname, "survivor_death_model"))
	{
		int iOwner = GetClientOfUserId(g_iSmiteDeathModelOwner);
		if (bIsValidClient(iOwner))
		{
			SDKHook(entity, SDKHook_SpawnPost, OnSmiteModelSpawnPost);
		}

		g_iSmiteDeathModelOwner = 0;
	}
}

void OnSmiteModelSpawnPost(int model)
{
	g_iSmiteDeathModelOwner = 0;

	SDKUnhook(model, SDKHook_SpawnPost, OnSmiteModelSpawnPost);

	if (!bIsValidEntity(model))
	{
		return;
	}

	RemoveEntity(model);
}

Action OnSmiteTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (MT_IsCorePluginEnabled() && bIsValidClient(victim, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE) && bIsValidEntity(inflictor) && damage > 0.0)
	{
		char sClassname[32];
		GetEntityClassname(inflictor, sClassname, sizeof sClassname);
		if (MT_IsTankSupported(attacker) && MT_IsCustomTankSupported(attacker) && (g_esSmiteCache[attacker].g_iSmiteHitMode == 0 || g_esSmiteCache[attacker].g_iSmiteHitMode == 1) && bIsSurvivor(victim) && g_esSmiteCache[attacker].g_iComboAbility == 0)
		{
			if ((!MT_HasAdminAccess(attacker) && !bHasAdminAccess(attacker, g_esSmiteAbility[g_esSmitePlayer[attacker].g_iTankType].g_iAccessFlags, g_esSmitePlayer[attacker].g_iAccessFlags)) || MT_IsAdminImmune(victim, attacker) || bIsAdminImmune(victim, g_esSmitePlayer[attacker].g_iTankType, g_esSmiteAbility[g_esSmitePlayer[attacker].g_iTankType].g_iImmunityFlags, g_esSmitePlayer[victim].g_iImmunityFlags))
			{
				return Plugin_Continue;
			}

			if (StrEqual(sClassname[7], "tank_claw") || StrEqual(sClassname, "tank_rock"))
			{
				vSmiteHit(victim, attacker, MT_GetRandomFloat(0.1, 100.0), g_esSmiteCache[attacker].g_flSmiteChance, g_esSmiteCache[attacker].g_iSmiteHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW);
			}
		}
		else if (MT_IsTankSupported(victim) && MT_IsCustomTankSupported(victim) && (g_esSmiteCache[victim].g_iSmiteHitMode == 0 || g_esSmiteCache[victim].g_iSmiteHitMode == 2) && bIsSurvivor(attacker) && g_esSmiteCache[victim].g_iComboAbility == 0)
		{
			if ((!MT_HasAdminAccess(victim) && !bHasAdminAccess(victim, g_esSmiteAbility[g_esSmitePlayer[victim].g_iTankType].g_iAccessFlags, g_esSmitePlayer[victim].g_iAccessFlags)) || MT_IsAdminImmune(attacker, victim) || bIsAdminImmune(attacker, g_esSmitePlayer[victim].g_iTankType, g_esSmiteAbility[g_esSmitePlayer[victim].g_iTankType].g_iImmunityFlags, g_esSmitePlayer[attacker].g_iImmunityFlags))
			{
				return Plugin_Continue;
			}

			if (StrEqual(sClassname[7], "melee"))
			{
				vSmiteHit(attacker, victim, MT_GetRandomFloat(0.1, 100.0), g_esSmiteCache[victim].g_flSmiteChance, g_esSmiteCache[victim].g_iSmiteHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE);
			}
		}
	}

	return Plugin_Continue;
}

#if defined MT_ABILITIES_MAIN2
void vSmitePluginCheck(ArrayList list)
#else
public void MT_OnPluginCheck(ArrayList list)
#endif
{
	list.PushString(MT_MENU_SMITE);
}

#if defined MT_ABILITIES_MAIN2
void vSmiteAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#else
public void MT_OnAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#endif
{
	list.PushString(MT_SMITE_SECTION);
	list2.PushString(MT_SMITE_SECTION2);
	list3.PushString(MT_SMITE_SECTION3);
	list4.PushString(MT_SMITE_SECTION4);
}

#if defined MT_ABILITIES_MAIN2
void vSmiteCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, const char[] classname)
#else
public void MT_OnCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
#endif
{
	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esSmiteCache[tank].g_iHumanAbility != 2)
	{
		return;
	}

	char sCombo[320], sSet[4][32];
	FormatEx(sCombo, sizeof sCombo, ",%s,", combo);
	FormatEx(sSet[0], sizeof sSet[], ",%s,", MT_SMITE_SECTION);
	FormatEx(sSet[1], sizeof sSet[], ",%s,", MT_SMITE_SECTION2);
	FormatEx(sSet[2], sizeof sSet[], ",%s,", MT_SMITE_SECTION3);
	FormatEx(sSet[3], sizeof sSet[], ",%s,", MT_SMITE_SECTION4);
	if (g_esSmiteCache[tank].g_iComboAbility == 1 && (StrContains(sCombo, sSet[0], false) != -1 || StrContains(sCombo, sSet[1], false) != -1 || StrContains(sCombo, sSet[2], false) != -1 || StrContains(sCombo, sSet[3], false) != -1))
	{
		char sAbilities[320], sSubset[10][32];
		strcopy(sAbilities, sizeof sAbilities, combo);
		ExplodeString(sAbilities, ",", sSubset, sizeof sSubset, sizeof sSubset[]);

		float flChance = 0.0, flDelay = 0.0;
		for (int iPos = 0; iPos < (sizeof sSubset); iPos++)
		{
			if (StrEqual(sSubset[iPos], MT_SMITE_SECTION, false) || StrEqual(sSubset[iPos], MT_SMITE_SECTION2, false) || StrEqual(sSubset[iPos], MT_SMITE_SECTION3, false) || StrEqual(sSubset[iPos], MT_SMITE_SECTION4, false))
			{
				flDelay = MT_GetCombinationSetting(tank, 4, iPos);

				switch (type)
				{
					case MT_COMBO_MAINRANGE:
					{
						if (g_esSmiteCache[tank].g_iSmiteAbility == 1)
						{
							switch (flDelay)
							{
								case 0.0: vSmiteAbility(tank, random, iPos);
								default:
								{
									DataPack dpCombo;
									CreateDataTimer(flDelay, tTimerSmiteCombo, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
									dpCombo.WriteCell(GetClientUserId(tank));
									dpCombo.WriteFloat(random);
									dpCombo.WriteCell(iPos);
								}
							}
						}
					}
					case MT_COMBO_MELEEHIT:
					{
						flChance = MT_GetCombinationSetting(tank, 1, iPos);

						switch (flDelay)
						{
							case 0.0:
							{
								if ((g_esSmiteCache[tank].g_iSmiteHitMode == 0 || g_esSmiteCache[tank].g_iSmiteHitMode == 1) && (StrEqual(classname[7], "tank_claw") || StrEqual(classname, "tank_rock")))
								{
									vSmiteHit(survivor, tank, random, flChance, g_esSmiteCache[tank].g_iSmiteHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW, iPos);
								}
								else if ((g_esSmiteCache[tank].g_iSmiteHitMode == 0 || g_esSmiteCache[tank].g_iSmiteHitMode == 2) && StrEqual(classname[7], "melee"))
								{
									vSmiteHit(survivor, tank, random, flChance, g_esSmiteCache[tank].g_iSmiteHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE, iPos);
								}
							}
							default:
							{
								DataPack dpCombo;
								CreateDataTimer(flDelay, tTimerSmiteCombo2, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
								dpCombo.WriteCell(GetClientUserId(survivor));
								dpCombo.WriteCell(GetClientUserId(tank));
								dpCombo.WriteFloat(random);
								dpCombo.WriteFloat(flChance);
								dpCombo.WriteCell(iPos);
								dpCombo.WriteString(classname);
							}
						}
					}
				}

				break;
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vSmiteConfigsLoad(int mode)
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
				g_esSmiteAbility[iIndex].g_iAccessFlags = 0;
				g_esSmiteAbility[iIndex].g_iImmunityFlags = 0;
				g_esSmiteAbility[iIndex].g_flCloseAreasOnly = 0.0;
				g_esSmiteAbility[iIndex].g_iComboAbility = 0;
				g_esSmiteAbility[iIndex].g_iHumanAbility = 0;
				g_esSmiteAbility[iIndex].g_iHumanAmmo = 5;
				g_esSmiteAbility[iIndex].g_iHumanCooldown = 0;
				g_esSmiteAbility[iIndex].g_iHumanRangeCooldown = 0;
				g_esSmiteAbility[iIndex].g_flOpenAreasOnly = 0.0;
				g_esSmiteAbility[iIndex].g_iRequiresHumans = 0;
				g_esSmiteAbility[iIndex].g_iSmiteAbility = 0;
				g_esSmiteAbility[iIndex].g_iSmiteEffect = 0;
				g_esSmiteAbility[iIndex].g_iSmiteMessage = 0;
				g_esSmiteAbility[iIndex].g_iSmiteBody = 1;
				g_esSmiteAbility[iIndex].g_flSmiteChance = 33.3;
				g_esSmiteAbility[iIndex].g_iSmiteCooldown = 0;
				g_esSmiteAbility[iIndex].g_iSmiteHit = 0;
				g_esSmiteAbility[iIndex].g_iSmiteHitMode = 0;
				g_esSmiteAbility[iIndex].g_flSmiteRange = 150.0;
				g_esSmiteAbility[iIndex].g_flSmiteRangeChance = 15.0;
				g_esSmiteAbility[iIndex].g_iSmiteRangeCooldown = 0;
			}
		}
		case 3:
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (bIsValidClient(iPlayer))
				{
					g_esSmitePlayer[iPlayer].g_iAccessFlags = 0;
					g_esSmitePlayer[iPlayer].g_iImmunityFlags = 0;
					g_esSmitePlayer[iPlayer].g_flCloseAreasOnly = 0.0;
					g_esSmitePlayer[iPlayer].g_iComboAbility = 0;
					g_esSmitePlayer[iPlayer].g_iHumanAbility = 0;
					g_esSmitePlayer[iPlayer].g_iHumanAmmo = 0;
					g_esSmitePlayer[iPlayer].g_iHumanCooldown = 0;
					g_esSmitePlayer[iPlayer].g_iHumanRangeCooldown = 0;
					g_esSmitePlayer[iPlayer].g_flOpenAreasOnly = 0.0;
					g_esSmitePlayer[iPlayer].g_iRequiresHumans = 0;
					g_esSmitePlayer[iPlayer].g_iSmiteAbility = 0;
					g_esSmitePlayer[iPlayer].g_iSmiteEffect = 0;
					g_esSmitePlayer[iPlayer].g_iSmiteMessage = 0;
					g_esSmitePlayer[iPlayer].g_iSmiteBody = 0;
					g_esSmitePlayer[iPlayer].g_flSmiteChance = 0.0;
					g_esSmitePlayer[iPlayer].g_iSmiteCooldown = 0;
					g_esSmitePlayer[iPlayer].g_iSmiteHit = 0;
					g_esSmitePlayer[iPlayer].g_iSmiteHitMode = 0;
					g_esSmitePlayer[iPlayer].g_flSmiteRange = 0.0;
					g_esSmitePlayer[iPlayer].g_flSmiteRangeChance = 0.0;
					g_esSmitePlayer[iPlayer].g_iSmiteRangeCooldown = 0;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vSmiteConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#else
public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#endif
{
	if (mode == 3 && bIsValidClient(admin))
	{
		g_esSmitePlayer[admin].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_SHAKE_SECTION, MT_SHAKE_SECTION2, MT_SHAKE_SECTION3, MT_SHAKE_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esSmitePlayer[admin].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esSmitePlayer[admin].g_iComboAbility = iGetKeyValue(subsection, MT_SMITE_SECTION, MT_SMITE_SECTION2, MT_SMITE_SECTION3, MT_SMITE_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esSmitePlayer[admin].g_iComboAbility, value, 0, 1);
		g_esSmitePlayer[admin].g_iHumanAbility = iGetKeyValue(subsection, MT_SMITE_SECTION, MT_SMITE_SECTION2, MT_SMITE_SECTION3, MT_SMITE_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esSmitePlayer[admin].g_iHumanAbility, value, 0, 2);
		g_esSmitePlayer[admin].g_iHumanAmmo = iGetKeyValue(subsection, MT_SMITE_SECTION, MT_SMITE_SECTION2, MT_SMITE_SECTION3, MT_SMITE_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esSmitePlayer[admin].g_iHumanAmmo, value, 0, 99999);
		g_esSmitePlayer[admin].g_iHumanCooldown = iGetKeyValue(subsection, MT_SMITE_SECTION, MT_SMITE_SECTION2, MT_SMITE_SECTION3, MT_SMITE_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esSmitePlayer[admin].g_iHumanCooldown, value, 0, 99999);
		g_esSmitePlayer[admin].g_iHumanRangeCooldown = iGetKeyValue(subsection, MT_SMITE_SECTION, MT_SMITE_SECTION2, MT_SMITE_SECTION3, MT_SMITE_SECTION4, key, "HumanRangeCooldown", "Human Range Cooldown", "Human_Range_Cooldown", "hrangecooldown", g_esSmitePlayer[admin].g_iHumanRangeCooldown, value, 0, 99999);
		g_esSmitePlayer[admin].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_SMITE_SECTION, MT_SMITE_SECTION2, MT_SMITE_SECTION3, MT_SMITE_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esSmitePlayer[admin].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esSmitePlayer[admin].g_iRequiresHumans = iGetKeyValue(subsection, MT_SMITE_SECTION, MT_SMITE_SECTION2, MT_SMITE_SECTION3, MT_SMITE_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esSmitePlayer[admin].g_iRequiresHumans, value, 0, 32);
		g_esSmitePlayer[admin].g_iSmiteAbility = iGetKeyValue(subsection, MT_SMITE_SECTION, MT_SMITE_SECTION2, MT_SMITE_SECTION3, MT_SMITE_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esSmitePlayer[admin].g_iSmiteAbility, value, 0, 1);
		g_esSmitePlayer[admin].g_iSmiteEffect = iGetKeyValue(subsection, MT_SMITE_SECTION, MT_SMITE_SECTION2, MT_SMITE_SECTION3, MT_SMITE_SECTION4, key, "AbilityEffect", "Ability Effect", "Ability_Effect", "effect", g_esSmitePlayer[admin].g_iSmiteEffect, value, 0, 7);
		g_esSmitePlayer[admin].g_iSmiteMessage = iGetKeyValue(subsection, MT_SMITE_SECTION, MT_SMITE_SECTION2, MT_SMITE_SECTION3, MT_SMITE_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esSmitePlayer[admin].g_iSmiteMessage, value, 0, 3);
		g_esSmitePlayer[admin].g_iSmiteBody = iGetKeyValue(subsection, MT_SMITE_SECTION, MT_SMITE_SECTION2, MT_SMITE_SECTION3, MT_SMITE_SECTION4, key, "SmiteBody", "Smite Body", "Smite_Body", "body", g_esSmitePlayer[admin].g_iSmiteBody, value, 0, 1);
		g_esSmitePlayer[admin].g_flSmiteChance = flGetKeyValue(subsection, MT_SMITE_SECTION, MT_SMITE_SECTION2, MT_SMITE_SECTION3, MT_SMITE_SECTION4, key, "SmiteChance", "Smite Chance", "Smite_Chance", "chance", g_esSmitePlayer[admin].g_flSmiteChance, value, 0.0, 100.0);
		g_esSmitePlayer[admin].g_iSmiteCooldown = iGetKeyValue(subsection, MT_SMITE_SECTION, MT_SMITE_SECTION2, MT_SMITE_SECTION3, MT_SMITE_SECTION4, key, "SmiteCooldown", "Smite Cooldown", "Smite_Cooldown", "cooldown", g_esSmitePlayer[admin].g_iSmiteCooldown, value, 0, 99999);
		g_esSmitePlayer[admin].g_iSmiteHit = iGetKeyValue(subsection, MT_SMITE_SECTION, MT_SMITE_SECTION2, MT_SMITE_SECTION3, MT_SMITE_SECTION4, key, "SmiteHit", "Smite Hit", "Smite_Hit", "hit", g_esSmitePlayer[admin].g_iSmiteHit, value, 0, 1);
		g_esSmitePlayer[admin].g_iSmiteHitMode = iGetKeyValue(subsection, MT_SMITE_SECTION, MT_SMITE_SECTION2, MT_SMITE_SECTION3, MT_SMITE_SECTION4, key, "SmiteHitMode", "Smite Hit Mode", "Smite_Hit_Mode", "hitmode", g_esSmitePlayer[admin].g_iSmiteHitMode, value, 0, 2);
		g_esSmitePlayer[admin].g_flSmiteRange = flGetKeyValue(subsection, MT_SMITE_SECTION, MT_SMITE_SECTION2, MT_SMITE_SECTION3, MT_SMITE_SECTION4, key, "SmiteRange", "Smite Range", "Smite_Range", "range", g_esSmitePlayer[admin].g_flSmiteRange, value, 1.0, 99999.0);
		g_esSmitePlayer[admin].g_flSmiteRangeChance = flGetKeyValue(subsection, MT_SMITE_SECTION, MT_SMITE_SECTION2, MT_SMITE_SECTION3, MT_SMITE_SECTION4, key, "SmiteRangeChance", "Smite Range Chance", "Smite_Range_Chance", "rangechance", g_esSmitePlayer[admin].g_flSmiteRangeChance, value, 0.0, 100.0);
		g_esSmitePlayer[admin].g_iSmiteRangeCooldown = iGetKeyValue(subsection, MT_SMITE_SECTION, MT_SMITE_SECTION2, MT_SMITE_SECTION3, MT_SMITE_SECTION4, key, "SmiteRangeCooldown", "Smite Range Cooldown", "Smite_Range_Cooldown", "rangecooldown", g_esSmitePlayer[admin].g_iSmiteRangeCooldown, value, 0, 99999);
		g_esSmitePlayer[admin].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_SMITE_SECTION, MT_SMITE_SECTION2, MT_SMITE_SECTION3, MT_SMITE_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esSmitePlayer[admin].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_SMITE_SECTION, MT_SMITE_SECTION2, MT_SMITE_SECTION3, MT_SMITE_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}

	if (mode < 3 && type > 0)
	{
		g_esSmiteAbility[type].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_SHAKE_SECTION, MT_SHAKE_SECTION2, MT_SHAKE_SECTION3, MT_SHAKE_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esSmiteAbility[type].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esSmiteAbility[type].g_iComboAbility = iGetKeyValue(subsection, MT_SMITE_SECTION, MT_SMITE_SECTION2, MT_SMITE_SECTION3, MT_SMITE_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esSmiteAbility[type].g_iComboAbility, value, 0, 1);
		g_esSmiteAbility[type].g_iHumanAbility = iGetKeyValue(subsection, MT_SMITE_SECTION, MT_SMITE_SECTION2, MT_SMITE_SECTION3, MT_SMITE_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esSmiteAbility[type].g_iHumanAbility, value, 0, 2);
		g_esSmiteAbility[type].g_iHumanAmmo = iGetKeyValue(subsection, MT_SMITE_SECTION, MT_SMITE_SECTION2, MT_SMITE_SECTION3, MT_SMITE_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esSmiteAbility[type].g_iHumanAmmo, value, 0, 99999);
		g_esSmiteAbility[type].g_iHumanCooldown = iGetKeyValue(subsection, MT_SMITE_SECTION, MT_SMITE_SECTION2, MT_SMITE_SECTION3, MT_SMITE_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esSmiteAbility[type].g_iHumanCooldown, value, 0, 99999);
		g_esSmiteAbility[type].g_iHumanRangeCooldown = iGetKeyValue(subsection, MT_SMITE_SECTION, MT_SMITE_SECTION2, MT_SMITE_SECTION3, MT_SMITE_SECTION4, key, "HumanRangeCooldown", "Human Range Cooldown", "Human_Range_Cooldown", "hrangecooldown", g_esSmiteAbility[type].g_iHumanRangeCooldown, value, 0, 99999);
		g_esSmiteAbility[type].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_SMITE_SECTION, MT_SMITE_SECTION2, MT_SMITE_SECTION3, MT_SMITE_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esSmiteAbility[type].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esSmiteAbility[type].g_iRequiresHumans = iGetKeyValue(subsection, MT_SMITE_SECTION, MT_SMITE_SECTION2, MT_SMITE_SECTION3, MT_SMITE_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esSmiteAbility[type].g_iRequiresHumans, value, 0, 32);
		g_esSmiteAbility[type].g_iSmiteAbility = iGetKeyValue(subsection, MT_SMITE_SECTION, MT_SMITE_SECTION2, MT_SMITE_SECTION3, MT_SMITE_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esSmiteAbility[type].g_iSmiteAbility, value, 0, 1);
		g_esSmiteAbility[type].g_iSmiteEffect = iGetKeyValue(subsection, MT_SMITE_SECTION, MT_SMITE_SECTION2, MT_SMITE_SECTION3, MT_SMITE_SECTION4, key, "AbilityEffect", "Ability Effect", "Ability_Effect", "effect", g_esSmiteAbility[type].g_iSmiteEffect, value, 0, 7);
		g_esSmiteAbility[type].g_iSmiteMessage = iGetKeyValue(subsection, MT_SMITE_SECTION, MT_SMITE_SECTION2, MT_SMITE_SECTION3, MT_SMITE_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esSmiteAbility[type].g_iSmiteMessage, value, 0, 3);
		g_esSmiteAbility[type].g_iSmiteBody = iGetKeyValue(subsection, MT_SMITE_SECTION, MT_SMITE_SECTION2, MT_SMITE_SECTION3, MT_SMITE_SECTION4, key, "SmiteBody", "Smite Body", "Smite_Body", "body", g_esSmiteAbility[type].g_iSmiteBody, value, 0, 1);
		g_esSmiteAbility[type].g_flSmiteChance = flGetKeyValue(subsection, MT_SMITE_SECTION, MT_SMITE_SECTION2, MT_SMITE_SECTION3, MT_SMITE_SECTION4, key, "SmiteChance", "Smite Chance", "Smite_Chance", "chance", g_esSmiteAbility[type].g_flSmiteChance, value, 0.0, 100.0);
		g_esSmiteAbility[type].g_iSmiteCooldown = iGetKeyValue(subsection, MT_SMITE_SECTION, MT_SMITE_SECTION2, MT_SMITE_SECTION3, MT_SMITE_SECTION4, key, "SmiteCooldown", "Smite Cooldown", "Smite_Cooldown", "cooldown", g_esSmiteAbility[type].g_iSmiteCooldown, value, 0, 99999);
		g_esSmiteAbility[type].g_iSmiteHit = iGetKeyValue(subsection, MT_SMITE_SECTION, MT_SMITE_SECTION2, MT_SMITE_SECTION3, MT_SMITE_SECTION4, key, "SmiteHit", "Smite Hit", "Smite_Hit", "hit", g_esSmiteAbility[type].g_iSmiteHit, value, 0, 1);
		g_esSmiteAbility[type].g_iSmiteHitMode = iGetKeyValue(subsection, MT_SMITE_SECTION, MT_SMITE_SECTION2, MT_SMITE_SECTION3, MT_SMITE_SECTION4, key, "SmiteHitMode", "Smite Hit Mode", "Smite_Hit_Mode", "hitmode", g_esSmiteAbility[type].g_iSmiteHitMode, value, 0, 2);
		g_esSmiteAbility[type].g_flSmiteRange = flGetKeyValue(subsection, MT_SMITE_SECTION, MT_SMITE_SECTION2, MT_SMITE_SECTION3, MT_SMITE_SECTION4, key, "SmiteRange", "Smite Range", "Smite_Range", "range", g_esSmiteAbility[type].g_flSmiteRange, value, 1.0, 99999.0);
		g_esSmiteAbility[type].g_flSmiteRangeChance = flGetKeyValue(subsection, MT_SMITE_SECTION, MT_SMITE_SECTION2, MT_SMITE_SECTION3, MT_SMITE_SECTION4, key, "SmiteRangeChance", "Smite Range Chance", "Smite_Range_Chance", "rangechance", g_esSmiteAbility[type].g_flSmiteRangeChance, value, 0.0, 100.0);
		g_esSmiteAbility[type].g_iSmiteRangeCooldown = iGetKeyValue(subsection, MT_SMITE_SECTION, MT_SMITE_SECTION2, MT_SMITE_SECTION3, MT_SMITE_SECTION4, key, "SmiteRangeCooldown", "Smite Range Cooldown", "Smite_Range_Cooldown", "rangecooldown", g_esSmiteAbility[type].g_iSmiteRangeCooldown, value, 0, 99999);
		g_esSmiteAbility[type].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_SMITE_SECTION, MT_SMITE_SECTION2, MT_SMITE_SECTION3, MT_SMITE_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esSmiteAbility[type].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_SMITE_SECTION, MT_SMITE_SECTION2, MT_SMITE_SECTION3, MT_SMITE_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}
}

#if defined MT_ABILITIES_MAIN2
void vSmiteSettingsCached(int tank, bool apply, int type)
#else
public void MT_OnSettingsCached(int tank, bool apply, int type)
#endif
{
	bool bHuman = bIsTank(tank, MT_CHECK_FAKECLIENT);
	g_esSmiteCache[tank].g_flCloseAreasOnly = flGetSettingValue(apply, bHuman, g_esSmitePlayer[tank].g_flCloseAreasOnly, g_esSmiteAbility[type].g_flCloseAreasOnly);
	g_esSmiteCache[tank].g_iComboAbility = iGetSettingValue(apply, bHuman, g_esSmitePlayer[tank].g_iComboAbility, g_esSmiteAbility[type].g_iComboAbility);
	g_esSmiteCache[tank].g_flSmiteChance = flGetSettingValue(apply, bHuman, g_esSmitePlayer[tank].g_flSmiteChance, g_esSmiteAbility[type].g_flSmiteChance);
	g_esSmiteCache[tank].g_flSmiteRange = flGetSettingValue(apply, bHuman, g_esSmitePlayer[tank].g_flSmiteRange, g_esSmiteAbility[type].g_flSmiteRange);
	g_esSmiteCache[tank].g_flSmiteRangeChance = flGetSettingValue(apply, bHuman, g_esSmitePlayer[tank].g_flSmiteRangeChance, g_esSmiteAbility[type].g_flSmiteRangeChance);
	g_esSmiteCache[tank].g_iHumanAbility = iGetSettingValue(apply, bHuman, g_esSmitePlayer[tank].g_iHumanAbility, g_esSmiteAbility[type].g_iHumanAbility);
	g_esSmiteCache[tank].g_iHumanAmmo = iGetSettingValue(apply, bHuman, g_esSmitePlayer[tank].g_iHumanAmmo, g_esSmiteAbility[type].g_iHumanAmmo);
	g_esSmiteCache[tank].g_iHumanCooldown = iGetSettingValue(apply, bHuman, g_esSmitePlayer[tank].g_iHumanCooldown, g_esSmiteAbility[type].g_iHumanCooldown);
	g_esSmiteCache[tank].g_iHumanRangeCooldown = iGetSettingValue(apply, bHuman, g_esSmitePlayer[tank].g_iHumanRangeCooldown, g_esSmiteAbility[type].g_iHumanRangeCooldown);
	g_esSmiteCache[tank].g_flOpenAreasOnly = flGetSettingValue(apply, bHuman, g_esSmitePlayer[tank].g_flOpenAreasOnly, g_esSmiteAbility[type].g_flOpenAreasOnly);
	g_esSmiteCache[tank].g_iRequiresHumans = iGetSettingValue(apply, bHuman, g_esSmitePlayer[tank].g_iRequiresHumans, g_esSmiteAbility[type].g_iRequiresHumans);
	g_esSmiteCache[tank].g_iSmiteAbility = iGetSettingValue(apply, bHuman, g_esSmitePlayer[tank].g_iSmiteAbility, g_esSmiteAbility[type].g_iSmiteAbility);
	g_esSmiteCache[tank].g_iSmiteBody = iGetSettingValue(apply, bHuman, g_esSmitePlayer[tank].g_iSmiteBody, g_esSmiteAbility[type].g_iSmiteBody);
	g_esSmiteCache[tank].g_iSmiteCooldown = iGetSettingValue(apply, bHuman, g_esSmitePlayer[tank].g_iSmiteCooldown, g_esSmiteAbility[type].g_iSmiteCooldown);
	g_esSmiteCache[tank].g_iSmiteEffect = iGetSettingValue(apply, bHuman, g_esSmitePlayer[tank].g_iSmiteEffect, g_esSmiteAbility[type].g_iSmiteEffect);
	g_esSmiteCache[tank].g_iSmiteHit = iGetSettingValue(apply, bHuman, g_esSmitePlayer[tank].g_iSmiteHit, g_esSmiteAbility[type].g_iSmiteHit);
	g_esSmiteCache[tank].g_iSmiteHitMode = iGetSettingValue(apply, bHuman, g_esSmitePlayer[tank].g_iSmiteHitMode, g_esSmiteAbility[type].g_iSmiteHitMode);
	g_esSmiteCache[tank].g_iSmiteMessage = iGetSettingValue(apply, bHuman, g_esSmitePlayer[tank].g_iSmiteMessage, g_esSmiteAbility[type].g_iSmiteMessage);
	g_esSmiteCache[tank].g_iSmiteRangeCooldown = iGetSettingValue(apply, bHuman, g_esSmitePlayer[tank].g_iSmiteRangeCooldown, g_esSmiteAbility[type].g_iSmiteRangeCooldown);
	g_esSmitePlayer[tank].g_iTankType = apply ? type : 0;
}

#if defined MT_ABILITIES_MAIN2
void vSmiteCopyStats(int oldTank, int newTank)
#else
public void MT_OnCopyStats(int oldTank, int newTank)
#endif
{
	vSmiteCopyStats2(oldTank, newTank);

	if (oldTank != newTank)
	{
		vRemoveSmite(oldTank);
	}
}

#if !defined MT_ABILITIES_MAIN2
public void MT_OnPluginUpdate()
{
	MT_ReloadPlugin(null);
}
#endif

#if defined MT_ABILITIES_MAIN2
void vSmiteEventFired(Event event, const char[] name)
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
			vSmiteCopyStats2(iBot, iTank);
			vRemoveSmite(iBot);
		}
	}
	else if (StrEqual(name, "player_bot_replace"))
	{
		int iTankId = event.GetInt("player"), iTank = GetClientOfUserId(iTankId),
			iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId);
		if (bIsValidClient(iTank) && bIsTank(iBot))
		{
			vSmiteCopyStats2(iTank, iBot);
			vRemoveSmite(iTank);
		}
	}
	else if (StrEqual(name, "player_death") || StrEqual(name, "player_spawn"))
	{
		int iTankId = event.GetInt("userid"), iTank = GetClientOfUserId(iTankId);
		if (MT_IsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME))
		{
			vRemoveSmite(iTank);
		}
	}
	else if (StrEqual(name, "mission_lost") || StrEqual(name, "round_start") || StrEqual(name, "round_end"))
	{
		vSmiteReset();
	}
}

#if defined MT_ABILITIES_MAIN2
void vSmiteAbilityActivated(int tank)
#else
public void MT_OnAbilityActivated(int tank)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esSmiteAbility[g_esSmitePlayer[tank].g_iTankType].g_iAccessFlags, g_esSmitePlayer[tank].g_iAccessFlags)) || g_esSmiteCache[tank].g_iHumanAbility == 0))
	{
		return;
	}

	if (MT_IsTankSupported(tank) && (!bIsTank(tank, MT_CHECK_FAKECLIENT) || g_esSmiteCache[tank].g_iHumanAbility != 1) && MT_IsCustomTankSupported(tank) && g_esSmiteCache[tank].g_iSmiteAbility == 1 && g_esSmiteCache[tank].g_iComboAbility == 0)
	{
		vSmiteAbility(tank, MT_GetRandomFloat(0.1, 100.0));
	}
}

#if defined MT_ABILITIES_MAIN2
void vSmiteButtonPressed(int tank, int button)
#else
public void MT_OnButtonPressed(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && MT_IsCustomTankSupported(tank))
	{
		if (bIsAreaNarrow(tank, g_esSmiteCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esSmiteCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esSmitePlayer[tank].g_iTankType) || (g_esSmiteCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esSmiteCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esSmiteAbility[g_esSmitePlayer[tank].g_iTankType].g_iAccessFlags, g_esSmitePlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		if ((button & MT_SUB_KEY) && g_esSmiteCache[tank].g_iSmiteAbility == 1 && g_esSmiteCache[tank].g_iHumanAbility == 1)
		{
			int iTime = GetTime();

			switch (g_esSmitePlayer[tank].g_iRangeCooldown == -1 || g_esSmitePlayer[tank].g_iRangeCooldown < iTime)
			{
				case true: vSmiteAbility(tank, MT_GetRandomFloat(0.1, 100.0));
				case false: MT_PrintToChat(tank, "%s %t", MT_TAG3, "SmiteHuman3", (g_esSmitePlayer[tank].g_iRangeCooldown - iTime));
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vSmiteChangeType(int tank, int oldType)
#else
public void MT_OnChangeType(int tank, int oldType, int newType, bool revert)
#endif
{
	if (oldType <= 0)
	{
		return;
	}

	vRemoveSmite(tank);
}

void vSmite(int survivor)
{
	float flPos[3], flStartPos[3];
	int iColor[4] = {255, 255, 255, 255};

	GetClientAbsOrigin(survivor, flPos);
	flPos[2] -= 26.0;
	flStartPos[0] = (flPos[0] + MT_GetRandomFloat(-500.0, 500.0));
	flStartPos[1] = (flPos[1] + MT_GetRandomFloat(-500.0, 500.0));
	flStartPos[2] = (flPos[2] + 800.0);

	TE_SetupBeamPoints(flStartPos, flPos, g_iSmiteSprite, 0, 0, 0, 0.2, 20.0, 10.0, 0, 1.0, iColor, 3);
	TE_SendToAll();

	TE_SetupSparks(flPos, view_as<float>({0.0, 0.0, 0.0}), 5000, 1000);
	TE_SendToAll();

	TE_SetupEnergySplash(flPos, view_as<float>({0.0, 0.0, 0.0}), false);
	TE_SendToAll();

	EmitAmbientSound(SOUND_EXPLOSION, flStartPos, survivor, SNDLEVEL_RAIDSIREN);
}

void vSmiteAbility(int tank, float random, int pos = -1)
{
	if (bIsAreaNarrow(tank, g_esSmiteCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esSmiteCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esSmitePlayer[tank].g_iTankType) || (g_esSmiteCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esSmiteCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esSmiteAbility[g_esSmitePlayer[tank].g_iTankType].g_iAccessFlags, g_esSmitePlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (g_esSmitePlayer[tank].g_iAmmoCount < g_esSmiteCache[tank].g_iHumanAmmo && g_esSmiteCache[tank].g_iHumanAmmo > 0))
	{
		g_esSmitePlayer[tank].g_bFailed = false;
		g_esSmitePlayer[tank].g_bNoAmmo = false;

		float flTankPos[3], flSurvivorPos[3];
		GetClientAbsOrigin(tank, flTankPos);
		float flRange = (pos != -1) ? MT_GetCombinationSetting(tank, 9, pos) : g_esSmiteCache[tank].g_flSmiteRange,
			flChance = (pos != -1) ? MT_GetCombinationSetting(tank, 10, pos) : g_esSmiteCache[tank].g_flSmiteRangeChance;
		int iSurvivorCount = 0;
		for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
		{
			if (bIsSurvivor(iSurvivor, MT_CHECK_INGAME|MT_CHECK_ALIVE) && !MT_IsAdminImmune(iSurvivor, tank) && !bIsAdminImmune(iSurvivor, g_esSmitePlayer[tank].g_iTankType, g_esSmiteAbility[g_esSmitePlayer[tank].g_iTankType].g_iImmunityFlags, g_esSmitePlayer[iSurvivor].g_iImmunityFlags))
			{
				GetClientAbsOrigin(iSurvivor, flSurvivorPos);
				if (GetVectorDistance(flTankPos, flSurvivorPos) <= flRange)
				{
					vSmiteHit(iSurvivor, tank, random, flChance, g_esSmiteCache[tank].g_iSmiteAbility, MT_MESSAGE_RANGE, MT_ATTACK_RANGE, pos);

					iSurvivorCount++;
				}
			}
		}

		if (iSurvivorCount == 0)
		{
			if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esSmiteCache[tank].g_iHumanAbility == 1)
			{
				MT_PrintToChat(tank, "%s %t", MT_TAG3, "SmiteHuman4");
			}
		}
	}
	else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esSmiteCache[tank].g_iHumanAbility == 1)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "SmiteAmmo");
	}
}

void vSmiteHit(int survivor, int tank, float random, float chance, int enabled, int messages, int flags, int pos = -1)
{
	if (bIsAreaNarrow(tank, g_esSmiteCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esSmiteCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esSmitePlayer[tank].g_iTankType) || (g_esSmiteCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esSmiteCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esSmiteAbility[g_esSmitePlayer[tank].g_iTankType].g_iAccessFlags, g_esSmitePlayer[tank].g_iAccessFlags)) || MT_IsAdminImmune(survivor, tank) || bIsAdminImmune(survivor, g_esSmitePlayer[tank].g_iTankType, g_esSmiteAbility[g_esSmitePlayer[tank].g_iTankType].g_iImmunityFlags, g_esSmitePlayer[survivor].g_iImmunityFlags))
	{
		return;
	}

	int iTime = GetTime();
	if (((flags & MT_ATTACK_RANGE) && g_esSmitePlayer[tank].g_iRangeCooldown != -1 && g_esSmitePlayer[tank].g_iRangeCooldown > iTime) || (((flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE)) && g_esSmitePlayer[tank].g_iCooldown != -1 && g_esSmitePlayer[tank].g_iCooldown > iTime))
	{
		return;
	}

	if (enabled == 1 && bIsSurvivor(survivor) && !MT_DoesSurvivorHaveRewardType(survivor, MT_REWARD_GODMODE))
	{
		if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE) || (g_esSmitePlayer[tank].g_iAmmoCount < g_esSmiteCache[tank].g_iHumanAmmo && g_esSmiteCache[tank].g_iHumanAmmo > 0))
		{
			if (random <= chance)
			{
				int iCooldown = -1;
				if ((flags & MT_ATTACK_RANGE) && (g_esSmitePlayer[tank].g_iRangeCooldown == -1 || g_esSmitePlayer[tank].g_iRangeCooldown < iTime))
				{
					if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esSmiteCache[tank].g_iHumanAbility == 1)
					{
						g_esSmitePlayer[tank].g_iAmmoCount++;

						MT_PrintToChat(tank, "%s %t", MT_TAG3, "SmiteHuman", g_esSmitePlayer[tank].g_iAmmoCount, g_esSmiteCache[tank].g_iHumanAmmo);
					}

					iCooldown = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 11, pos)) : g_esSmiteCache[tank].g_iSmiteRangeCooldown;
					iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esSmiteCache[tank].g_iHumanAbility == 1 && g_esSmitePlayer[tank].g_iAmmoCount < g_esSmiteCache[tank].g_iHumanAmmo && g_esSmiteCache[tank].g_iHumanAmmo > 0) ? g_esSmiteCache[tank].g_iHumanRangeCooldown : iCooldown;
					g_esSmitePlayer[tank].g_iRangeCooldown = (iTime + iCooldown);
					if (g_esSmitePlayer[tank].g_iRangeCooldown != -1 && g_esSmitePlayer[tank].g_iRangeCooldown > iTime)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "SmiteHuman5", (g_esSmitePlayer[tank].g_iRangeCooldown - iTime));
					}
				}
				else if (((flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE)) && (g_esSmitePlayer[tank].g_iCooldown == -1 || g_esSmitePlayer[tank].g_iCooldown < iTime))
				{
					iCooldown = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 2, pos)) : g_esSmiteCache[tank].g_iSmiteCooldown;
					iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esSmiteCache[tank].g_iHumanAbility == 1) ? g_esSmiteCache[tank].g_iHumanCooldown : iCooldown;
					g_esSmitePlayer[tank].g_iCooldown = (iTime + iCooldown);
					if (g_esSmitePlayer[tank].g_iCooldown != -1 && g_esSmitePlayer[tank].g_iCooldown > iTime)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "SmiteHuman5", (g_esSmitePlayer[tank].g_iCooldown - iTime));
					}
				}

				if (g_esSmiteCache[tank].g_iSmiteBody == 1)
				{
					g_iSmiteDeathModelOwner = GetClientUserId(survivor);
				}

				vSmite(survivor);
				ForcePlayerSuicide(survivor);
				vScreenEffect(survivor, tank, g_esSmiteCache[tank].g_iSmiteEffect, flags);

				if (g_esSmiteCache[tank].g_iSmiteMessage & messages)
				{
					char sTankName[33];
					MT_GetTankName(tank, sTankName);
					MT_PrintToChatAll("%s %t", MT_TAG2, "Smite", sTankName, survivor);
					MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Smite", LANG_SERVER, sTankName, survivor);
				}
			}
			else if ((flags & MT_ATTACK_RANGE) && (g_esSmitePlayer[tank].g_iRangeCooldown == -1 || g_esSmitePlayer[tank].g_iRangeCooldown < iTime))
			{
				if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esSmiteCache[tank].g_iHumanAbility == 1 && !g_esSmitePlayer[tank].g_bFailed)
				{
					g_esSmitePlayer[tank].g_bFailed = true;

					MT_PrintToChat(tank, "%s %t", MT_TAG3, "SmiteHuman2");
				}
			}
		}
		else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esSmiteCache[tank].g_iHumanAbility == 1 && !g_esSmitePlayer[tank].g_bNoAmmo)
		{
			g_esSmitePlayer[tank].g_bNoAmmo = true;

			MT_PrintToChat(tank, "%s %t", MT_TAG3, "SmiteAmmo");
		}
	}
}

void vSmiteCopyStats2(int oldTank, int newTank)
{
	g_esSmitePlayer[newTank].g_iAmmoCount = g_esSmitePlayer[oldTank].g_iAmmoCount;
	g_esSmitePlayer[newTank].g_iCooldown = g_esSmitePlayer[oldTank].g_iCooldown;
	g_esSmitePlayer[newTank].g_iRangeCooldown = g_esSmitePlayer[oldTank].g_iRangeCooldown;
}

void vRemoveSmite(int tank)
{
	g_esSmitePlayer[tank].g_bFailed = false;
	g_esSmitePlayer[tank].g_bNoAmmo = false;
	g_esSmitePlayer[tank].g_iAmmoCount = 0;
	g_esSmitePlayer[tank].g_iCooldown = -1;
	g_esSmitePlayer[tank].g_iRangeCooldown = -1;
}

void vSmiteReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
		{
			vRemoveSmite(iPlayer);
		}
	}
}

Action tTimerSmiteCombo(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esSmiteAbility[g_esSmitePlayer[iTank].g_iTankType].g_iAccessFlags, g_esSmitePlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esSmitePlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esSmiteCache[iTank].g_iSmiteAbility == 0)
	{
		return Plugin_Stop;
	}

	float flRandom = pack.ReadFloat();
	int iPos = pack.ReadCell();
	vSmiteAbility(iTank, flRandom, iPos);

	return Plugin_Continue;
}

Action tTimerSmiteCombo2(Handle timer, DataPack pack)
{
	pack.Reset();

	int iSurvivor = GetClientOfUserId(pack.ReadCell());
	if (!bIsSurvivor(iSurvivor))
	{
		return Plugin_Stop;
	}

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esSmiteAbility[g_esSmitePlayer[iTank].g_iTankType].g_iAccessFlags, g_esSmitePlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esSmitePlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esSmiteCache[iTank].g_iSmiteHit == 0)
	{
		return Plugin_Stop;
	}

	float flRandom = pack.ReadFloat(), flChance = pack.ReadFloat();
	int iPos = pack.ReadCell();
	char sClassname[32];
	pack.ReadString(sClassname, sizeof sClassname);
	if ((g_esSmiteCache[iTank].g_iSmiteHitMode == 0 || g_esSmiteCache[iTank].g_iSmiteHitMode == 1) && (StrEqual(sClassname[7], "tank_claw") || StrEqual(sClassname, "tank_rock")))
	{
		vSmiteHit(iSurvivor, iTank, flRandom, flChance, g_esSmiteCache[iTank].g_iSmiteHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW, iPos);
	}
	else if ((g_esSmiteCache[iTank].g_iSmiteHitMode == 0 || g_esSmiteCache[iTank].g_iSmiteHitMode == 2) && StrEqual(sClassname[7], "melee"))
	{
		vSmiteHit(iSurvivor, iTank, flRandom, flChance, g_esSmiteCache[iTank].g_iSmiteHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE, iPos);
	}

	return Plugin_Continue;
}