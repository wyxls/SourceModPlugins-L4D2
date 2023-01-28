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

#define MT_SPAM_COMPILE_METHOD 0 // 0: packaged, 1: standalone

#if !defined MT_ABILITIES_MAIN2
	#if MT_SPAM_COMPILE_METHOD == 1
		#include <sourcemod>
		#include <mutant_tanks>
	#else
		#error This file must be inside "scripting/mutant_tanks/abilities2" while compiling "mt_abilities2.sp" to include its content.
	#endif
public Plugin myinfo =
{
	name = "[MT] Spam Ability",
	author = MT_AUTHOR,
	description = "The Mutant Tank spams rocks at survivors.",
	version = MT_VERSION,
	url = MT_URL
};

bool g_bDedicated;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion evEngine = GetEngineVersion();
	if (evEngine != Engine_Left4Dead && evEngine != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "\"[MT] Spam Ability\" only supports Left 4 Dead 1 & 2.");

		return APLRes_SilentFailure;
	}

	g_bDedicated = IsDedicatedServer();

	return APLRes_Success;
}
#else
	#if MT_SPAM_COMPILE_METHOD == 1
		#error This file must be compiled as a standalone plugin.
	#endif
#endif

#define MT_SPAM_SECTION "spamability"
#define MT_SPAM_SECTION2 "spam ability"
#define MT_SPAM_SECTION3 "spam_ability"
#define MT_SPAM_SECTION4 "spam"

#define MT_MENU_SPAM "Spam Ability"

enum struct esSpamPlayer
{
	bool g_bActivated;

	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flSpamChance;
	float g_flSpamInterval;

	int g_iAccessFlags;
	int g_iAmmoCount;
	int g_iComboAbility;
	int g_iCooldown;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanDuration;
	int g_iHumanMode;
	int g_iImmunityFlags;
	int g_iLauncher;
	int g_iRequiresHumans;
	int g_iSpamAbility;
	int g_iSpamCooldown;
	int g_iSpamDamage;
	int g_iSpamDuration;
	int g_iSpamMessage;
	int g_iTankType;
}

esSpamPlayer g_esSpamPlayer[MAXPLAYERS + 1];

enum struct esSpamAbility
{
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flSpamChance;
	float g_flSpamInterval;

	int g_iAccessFlags;
	int g_iComboAbility;
	int g_iComboPosition;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanDuration;
	int g_iHumanMode;
	int g_iImmunityFlags;
	int g_iRequiresHumans;
	int g_iSpamAbility;
	int g_iSpamCooldown;
	int g_iSpamDamage;
	int g_iSpamDuration;
	int g_iSpamMessage;
}

esSpamAbility g_esSpamAbility[MT_MAXTYPES + 1];

enum struct esSpamCache
{
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flSpamChance;
	float g_flSpamInterval;

	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanDuration;
	int g_iHumanMode;
	int g_iRequiresHumans;
	int g_iSpamAbility;
	int g_iSpamCooldown;
	int g_iSpamDamage;
	int g_iSpamDuration;
	int g_iSpamMessage;
}

esSpamCache g_esSpamCache[MAXPLAYERS + 1];

#if !defined MT_ABILITIES_MAIN2
public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");
	LoadTranslations("mutant_tanks_names.phrases");

	RegConsoleCmd("sm_mt_spam", cmdSpamInfo, "View information about the Spam ability.");
}
#endif

#if defined MT_ABILITIES_MAIN2
void vSpamMapStart()
#else
public void OnMapStart()
#endif
{
	vSpamReset();
}

#if defined MT_ABILITIES_MAIN2
void vSpamClientPutInServer(int client)
#else
public void OnClientPutInServer(int client)
#endif
{
	SDKHook(client, SDKHook_OnTakeDamage, OnSpamTakeDamage);
	vRemoveSpam(client);
}

#if defined MT_ABILITIES_MAIN2
void vSpamClientDisconnect_Post(int client)
#else
public void OnClientDisconnect_Post(int client)
#endif
{
	vRemoveSpam(client);
}

#if defined MT_ABILITIES_MAIN2
void vSpamMapEnd()
#else
public void OnMapEnd()
#endif
{
	vSpamReset();
}

#if !defined MT_ABILITIES_MAIN2
Action cmdSpamInfo(int client, int args)
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
		case false: vSpamMenu(client, MT_SPAM_SECTION4, 0);
	}

	return Plugin_Handled;
}
#endif

void vSpamMenu(int client, const char[] name, int item)
{
	if (StrContains(MT_SPAM_SECTION4, name, false) == -1)
	{
		return;
	}

	Menu mAbilityMenu = new Menu(iSpamMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Spam Ability Information");
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

int iSpamMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esSpamCache[param1].g_iSpamAbility == 0) ? "AbilityStatus1" : "AbilityStatus2");
				case 1: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityAmmo", (g_esSpamCache[param1].g_iHumanAmmo - g_esSpamPlayer[param1].g_iAmmoCount), g_esSpamCache[param1].g_iHumanAmmo);
				case 2: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityButtons");
				case 3: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esSpamCache[param1].g_iHumanMode == 0) ? "AbilityButtonMode1" : "AbilityButtonMode2");
				case 4: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityCooldown", ((g_esSpamCache[param1].g_iHumanAbility == 1) ? g_esSpamCache[param1].g_iHumanCooldown : g_esSpamCache[param1].g_iSpamCooldown));
				case 5: MT_PrintToChat(param1, "%s %t", MT_TAG3, "SpamDetails");
				case 6: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityDuration2", ((g_esSpamCache[param1].g_iHumanAbility == 1) ? g_esSpamCache[param1].g_iHumanDuration : g_esSpamCache[param1].g_iSpamDuration));
				case 7: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esSpamCache[param1].g_iHumanAbility == 0) ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME))
			{
				vSpamMenu(param1, MT_SPAM_SECTION4, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pSpam = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "SpamMenu", param1);
			pSpam.SetTitle(sMenuTitle);
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

#if defined MT_ABILITIES_MAIN2
void vSpamDisplayMenu(Menu menu)
#else
public void MT_OnDisplayMenu(Menu menu)
#endif
{
	menu.AddItem(MT_MENU_SPAM, MT_MENU_SPAM);
}

#if defined MT_ABILITIES_MAIN2
void vSpamMenuItemSelected(int client, const char[] info)
#else
public void MT_OnMenuItemSelected(int client, const char[] info)
#endif
{
	if (StrEqual(info, MT_MENU_SPAM, false))
	{
		vSpamMenu(client, MT_SPAM_SECTION4, 0);
	}
}

#if defined MT_ABILITIES_MAIN2
void vSpamMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#else
public void MT_OnMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#endif
{
	if (StrEqual(info, MT_MENU_SPAM, false))
	{
		FormatEx(buffer, size, "%T", "SpamMenu2", client);
	}
}

Action OnSpamTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (MT_IsCorePluginEnabled() && bIsValidClient(victim, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE) && bIsValidEntity(inflictor) && damage > 0.0)
	{
		char sClassname[32];
		GetEntityClassname(inflictor, sClassname, sizeof sClassname);
		if (StrEqual(sClassname, "tank_rock"))
		{
			int iLauncher = GetEntPropEnt(inflictor, Prop_Data, "m_hOwnerEntity"),
				iThrower = GetEntPropEnt(inflictor, Prop_Data, "m_hThrower");
			if (bIsValidEntity(iLauncher) && bIsTank(iThrower, MT_CHECK_INDEX|MT_CHECK_INGAME))
			{
				int iTank = GetEntPropEnt(iLauncher, Prop_Data, "m_hOwnerEntity");
				if (iThrower == iTank && MT_IsTankSupported(iTank) && MT_IsCustomTankSupported(iTank) && g_esSpamCache[iTank].g_iSpamAbility == 1 && g_esSpamPlayer[iTank].g_iLauncher != INVALID_ENT_REFERENCE && iLauncher == EntRefToEntIndex(g_esSpamPlayer[iTank].g_iLauncher) && (MT_HasAdminAccess(iTank) || bHasAdminAccess(iTank, g_esSpamAbility[g_esSpamPlayer[iTank].g_iTankType].g_iAccessFlags, g_esSpamPlayer[iTank].g_iAccessFlags)))
				{
					if (bIsInfected(victim) || (bIsSurvivor(victim) && (MT_IsAdminImmune(victim, iTank) || bIsAdminImmune(victim, g_esSpamPlayer[iTank].g_iTankType, g_esSpamAbility[g_esSpamPlayer[iTank].g_iTankType].g_iImmunityFlags, g_esSpamPlayer[victim].g_iImmunityFlags))))
					{
						return Plugin_Handled;
					}

					int iPos = g_esSpamAbility[g_esSpamPlayer[iTank].g_iTankType].g_iComboPosition;
					float flDamage = (iPos != -1) ? MT_GetCombinationSetting(iTank, 3, iPos) : float(g_esSpamCache[iTank].g_iSpamDamage);
					damage = MT_GetScaledDamage(flDamage);

					return Plugin_Changed;
				}
			}
		}
	}

	return Plugin_Continue;
}

#if defined MT_ABILITIES_MAIN2
void vSpamPluginCheck(ArrayList list)
#else
public void MT_OnPluginCheck(ArrayList list)
#endif
{
	list.PushString(MT_MENU_SPAM);
}

#if defined MT_ABILITIES_MAIN2
void vSpamAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#else
public void MT_OnAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#endif
{
	list.PushString(MT_SPAM_SECTION);
	list2.PushString(MT_SPAM_SECTION2);
	list3.PushString(MT_SPAM_SECTION3);
	list4.PushString(MT_SPAM_SECTION4);
}

#if defined MT_ABILITIES_MAIN2
void vSpamCombineAbilities(int tank, int type, const float random, const char[] combo)
#else
public void MT_OnCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
#endif
{
	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esSpamCache[tank].g_iHumanAbility != 2)
	{
		g_esSpamAbility[g_esSpamPlayer[tank].g_iTankType].g_iComboPosition = -1;

		return;
	}

	g_esSpamAbility[g_esSpamPlayer[tank].g_iTankType].g_iComboPosition = -1;

	char sCombo[320], sSet[4][32];
	FormatEx(sCombo, sizeof sCombo, ",%s,", combo);
	FormatEx(sSet[0], sizeof sSet[], ",%s,", MT_SPAM_SECTION);
	FormatEx(sSet[1], sizeof sSet[], ",%s,", MT_SPAM_SECTION2);
	FormatEx(sSet[2], sizeof sSet[], ",%s,", MT_SPAM_SECTION3);
	FormatEx(sSet[3], sizeof sSet[], ",%s,", MT_SPAM_SECTION4);
	if (StrContains(sCombo, sSet[0], false) != -1 || StrContains(sCombo, sSet[1], false) != -1 || StrContains(sCombo, sSet[2], false) != -1 || StrContains(sCombo, sSet[3], false) != -1)
	{
		if (type == MT_COMBO_MAINRANGE && g_esSpamCache[tank].g_iSpamAbility == 1 && g_esSpamCache[tank].g_iComboAbility == 1 && !g_esSpamPlayer[tank].g_bActivated)
		{
			char sAbilities[320], sSubset[10][32];
			strcopy(sAbilities, sizeof sAbilities, combo);
			ExplodeString(sAbilities, ",", sSubset, sizeof sSubset, sizeof sSubset[]);

			float flDelay = 0.0;
			for (int iPos = 0; iPos < (sizeof sSubset); iPos++)
			{
				if (StrEqual(sSubset[iPos], MT_SPAM_SECTION, false) || StrEqual(sSubset[iPos], MT_SPAM_SECTION2, false) || StrEqual(sSubset[iPos], MT_SPAM_SECTION3, false) || StrEqual(sSubset[iPos], MT_SPAM_SECTION4, false))
				{
					g_esSpamAbility[g_esSpamPlayer[tank].g_iTankType].g_iComboPosition = iPos;

					if (random <= MT_GetCombinationSetting(tank, 1, iPos))
					{
						flDelay = MT_GetCombinationSetting(tank, 4, iPos);

						switch (flDelay)
						{
							case 0.0: vSpam(tank, iPos);
							default:
							{
								DataPack dpCombo;
								CreateDataTimer(flDelay, tTimerSpamCombo, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
								dpCombo.WriteCell(GetClientUserId(tank));
								dpCombo.WriteCell(iPos);
							}
						}
					}

					break;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vSpamConfigsLoad(int mode)
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
				g_esSpamAbility[iIndex].g_iAccessFlags = 0;
				g_esSpamAbility[iIndex].g_iImmunityFlags = 0;
				g_esSpamAbility[iIndex].g_flCloseAreasOnly = 0.0;
				g_esSpamAbility[iIndex].g_iComboAbility = 0;
				g_esSpamAbility[iIndex].g_iComboPosition = -1;
				g_esSpamAbility[iIndex].g_iHumanAbility = 0;
				g_esSpamAbility[iIndex].g_iHumanAmmo = 5;
				g_esSpamAbility[iIndex].g_iHumanCooldown = 0;
				g_esSpamAbility[iIndex].g_iHumanDuration = 5;
				g_esSpamAbility[iIndex].g_iHumanMode = 1;
				g_esSpamAbility[iIndex].g_flOpenAreasOnly = 0.0;
				g_esSpamAbility[iIndex].g_iRequiresHumans = 0;
				g_esSpamAbility[iIndex].g_iSpamAbility = 0;
				g_esSpamAbility[iIndex].g_iSpamMessage = 0;
				g_esSpamAbility[iIndex].g_flSpamChance = 33.3;
				g_esSpamAbility[iIndex].g_iSpamCooldown = 0;
				g_esSpamAbility[iIndex].g_iSpamDamage = 5;
				g_esSpamAbility[iIndex].g_iSpamDuration = 5;
				g_esSpamAbility[iIndex].g_flSpamInterval = 0.5;
			}
		}
		case 3:
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (bIsValidClient(iPlayer))
				{
					g_esSpamPlayer[iPlayer].g_iAccessFlags = 0;
					g_esSpamPlayer[iPlayer].g_iImmunityFlags = 0;
					g_esSpamPlayer[iPlayer].g_flCloseAreasOnly = 0.0;
					g_esSpamPlayer[iPlayer].g_iComboAbility = 0;
					g_esSpamPlayer[iPlayer].g_iHumanAbility = 0;
					g_esSpamPlayer[iPlayer].g_iHumanAmmo = 0;
					g_esSpamPlayer[iPlayer].g_iHumanCooldown = 0;
					g_esSpamPlayer[iPlayer].g_iHumanDuration = 0;
					g_esSpamPlayer[iPlayer].g_iHumanMode = 0;
					g_esSpamPlayer[iPlayer].g_flOpenAreasOnly = 0.0;
					g_esSpamPlayer[iPlayer].g_iRequiresHumans = 0;
					g_esSpamPlayer[iPlayer].g_iSpamAbility = 0;
					g_esSpamPlayer[iPlayer].g_iSpamMessage = 0;
					g_esSpamPlayer[iPlayer].g_flSpamChance = 0.0;
					g_esSpamPlayer[iPlayer].g_iSpamCooldown = 0;
					g_esSpamPlayer[iPlayer].g_iSpamDamage = 0;
					g_esSpamPlayer[iPlayer].g_iSpamDuration = 0;
					g_esSpamPlayer[iPlayer].g_flSpamInterval = 0.0;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vSpamConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#else
public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#endif
{
	if (mode == 3 && bIsValidClient(admin))
	{
		g_esSpamPlayer[admin].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_SHAKE_SECTION, MT_SHAKE_SECTION2, MT_SHAKE_SECTION3, MT_SHAKE_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esSpamPlayer[admin].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esSpamPlayer[admin].g_iComboAbility = iGetKeyValue(subsection, MT_SPAM_SECTION, MT_SPAM_SECTION2, MT_SPAM_SECTION3, MT_SPAM_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esSpamPlayer[admin].g_iComboAbility, value, 0, 1);
		g_esSpamPlayer[admin].g_iHumanAbility = iGetKeyValue(subsection, MT_SPAM_SECTION, MT_SPAM_SECTION2, MT_SPAM_SECTION3, MT_SPAM_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esSpamPlayer[admin].g_iHumanAbility, value, 0, 2);
		g_esSpamPlayer[admin].g_iHumanAmmo = iGetKeyValue(subsection, MT_SPAM_SECTION, MT_SPAM_SECTION2, MT_SPAM_SECTION3, MT_SPAM_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esSpamPlayer[admin].g_iHumanAmmo, value, 0, 99999);
		g_esSpamPlayer[admin].g_iHumanCooldown = iGetKeyValue(subsection, MT_SPAM_SECTION, MT_SPAM_SECTION2, MT_SPAM_SECTION3, MT_SPAM_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esSpamPlayer[admin].g_iHumanCooldown, value, 0, 99999);
		g_esSpamPlayer[admin].g_iHumanDuration = iGetKeyValue(subsection, MT_SPAM_SECTION, MT_SPAM_SECTION2, MT_SPAM_SECTION3, MT_SPAM_SECTION4, key, "HumanDuration", "Human Duration", "Human_Duration", "hduration", g_esSpamPlayer[admin].g_iHumanDuration, value, 0, 99999);
		g_esSpamPlayer[admin].g_iHumanMode = iGetKeyValue(subsection, MT_SPAM_SECTION, MT_SPAM_SECTION2, MT_SPAM_SECTION3, MT_SPAM_SECTION4, key, "HumanMode", "Human Mode", "Human_Mode", "hmode", g_esSpamPlayer[admin].g_iHumanMode, value, 0, 1);
		g_esSpamPlayer[admin].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_SPAM_SECTION, MT_SPAM_SECTION2, MT_SPAM_SECTION3, MT_SPAM_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esSpamPlayer[admin].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esSpamPlayer[admin].g_iRequiresHumans = iGetKeyValue(subsection, MT_SPAM_SECTION, MT_SPAM_SECTION2, MT_SPAM_SECTION3, MT_SPAM_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esSpamPlayer[admin].g_iRequiresHumans, value, 0, 32);
		g_esSpamPlayer[admin].g_iSpamAbility = iGetKeyValue(subsection, MT_SPAM_SECTION, MT_SPAM_SECTION2, MT_SPAM_SECTION3, MT_SPAM_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esSpamPlayer[admin].g_iSpamAbility, value, 0, 1);
		g_esSpamPlayer[admin].g_iSpamMessage = iGetKeyValue(subsection, MT_SPAM_SECTION, MT_SPAM_SECTION2, MT_SPAM_SECTION3, MT_SPAM_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esSpamPlayer[admin].g_iSpamMessage, value, 0, 1);
		g_esSpamPlayer[admin].g_flSpamChance = flGetKeyValue(subsection, MT_SPAM_SECTION, MT_SPAM_SECTION2, MT_SPAM_SECTION3, MT_SPAM_SECTION4, key, "SpamChance", "Spam Chance", "Spam_Chance", "chance", g_esSpamPlayer[admin].g_flSpamChance, value, 0.0, 100.0);
		g_esSpamPlayer[admin].g_iSpamCooldown = iGetKeyValue(subsection, MT_SPAM_SECTION, MT_SPAM_SECTION2, MT_SPAM_SECTION3, MT_SPAM_SECTION4, key, "SpamCooldown", "Spam Cooldown", "Spam_Cooldown", "cooldown", g_esSpamPlayer[admin].g_iSpamCooldown, value, 0, 99999);
		g_esSpamPlayer[admin].g_iSpamDamage = iGetKeyValue(subsection, MT_SPAM_SECTION, MT_SPAM_SECTION2, MT_SPAM_SECTION3, MT_SPAM_SECTION4, key, "SpamDamage", "Spam Damage", "Spam_Damage", "damage", g_esSpamPlayer[admin].g_iSpamDamage, value, 0, 99999);
		g_esSpamPlayer[admin].g_iSpamDuration = iGetKeyValue(subsection, MT_SPAM_SECTION, MT_SPAM_SECTION2, MT_SPAM_SECTION3, MT_SPAM_SECTION4, key, "SpamDuration", "Spam Duration", "Spam_Duration", "duration", g_esSpamPlayer[admin].g_iSpamDuration, value, 0, 99999);
		g_esSpamPlayer[admin].g_flSpamInterval = flGetKeyValue(subsection, MT_SPAM_SECTION, MT_SPAM_SECTION2, MT_SPAM_SECTION3, MT_SPAM_SECTION4, key, "SpamInterval", "Spam Interval", "Spam_Interval", "interval", g_esSpamPlayer[admin].g_flSpamInterval, value, 0.1, 1.0);
		g_esSpamPlayer[admin].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_SPAM_SECTION, MT_SPAM_SECTION2, MT_SPAM_SECTION3, MT_SPAM_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esSpamPlayer[admin].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_SPAM_SECTION, MT_SPAM_SECTION2, MT_SPAM_SECTION3, MT_SPAM_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}

	if (mode < 3 && type > 0)
	{
		g_esSpamAbility[type].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_SHAKE_SECTION, MT_SHAKE_SECTION2, MT_SHAKE_SECTION3, MT_SHAKE_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esSpamAbility[type].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esSpamAbility[type].g_iComboAbility = iGetKeyValue(subsection, MT_SPAM_SECTION, MT_SPAM_SECTION2, MT_SPAM_SECTION3, MT_SPAM_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esSpamAbility[type].g_iComboAbility, value, 0, 1);
		g_esSpamAbility[type].g_iHumanAbility = iGetKeyValue(subsection, MT_SPAM_SECTION, MT_SPAM_SECTION2, MT_SPAM_SECTION3, MT_SPAM_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esSpamAbility[type].g_iHumanAbility, value, 0, 2);
		g_esSpamAbility[type].g_iHumanAmmo = iGetKeyValue(subsection, MT_SPAM_SECTION, MT_SPAM_SECTION2, MT_SPAM_SECTION3, MT_SPAM_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esSpamAbility[type].g_iHumanAmmo, value, 0, 99999);
		g_esSpamAbility[type].g_iHumanCooldown = iGetKeyValue(subsection, MT_SPAM_SECTION, MT_SPAM_SECTION2, MT_SPAM_SECTION3, MT_SPAM_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esSpamAbility[type].g_iHumanCooldown, value, 0, 99999);
		g_esSpamAbility[type].g_iHumanDuration = iGetKeyValue(subsection, MT_SPAM_SECTION, MT_SPAM_SECTION2, MT_SPAM_SECTION3, MT_SPAM_SECTION4, key, "HumanDuration", "Human Duration", "Human_Duration", "hduration", g_esSpamAbility[type].g_iHumanDuration, value, 0, 99999);
		g_esSpamAbility[type].g_iHumanMode = iGetKeyValue(subsection, MT_SPAM_SECTION, MT_SPAM_SECTION2, MT_SPAM_SECTION3, MT_SPAM_SECTION4, key, "HumanMode", "Human Mode", "Human_Mode", "hmode", g_esSpamAbility[type].g_iHumanMode, value, 0, 1);
		g_esSpamAbility[type].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_SPAM_SECTION, MT_SPAM_SECTION2, MT_SPAM_SECTION3, MT_SPAM_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esSpamAbility[type].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esSpamAbility[type].g_iRequiresHumans = iGetKeyValue(subsection, MT_SPAM_SECTION, MT_SPAM_SECTION2, MT_SPAM_SECTION3, MT_SPAM_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esSpamAbility[type].g_iRequiresHumans, value, 0, 32);
		g_esSpamAbility[type].g_iSpamAbility = iGetKeyValue(subsection, MT_SPAM_SECTION, MT_SPAM_SECTION2, MT_SPAM_SECTION3, MT_SPAM_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esSpamAbility[type].g_iSpamAbility, value, 0, 1);
		g_esSpamAbility[type].g_iSpamMessage = iGetKeyValue(subsection, MT_SPAM_SECTION, MT_SPAM_SECTION2, MT_SPAM_SECTION3, MT_SPAM_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esSpamAbility[type].g_iSpamMessage, value, 0, 1);
		g_esSpamAbility[type].g_flSpamChance = flGetKeyValue(subsection, MT_SPAM_SECTION, MT_SPAM_SECTION2, MT_SPAM_SECTION3, MT_SPAM_SECTION4, key, "SpamChance", "Spam Chance", "Spam_Chance", "chance", g_esSpamAbility[type].g_flSpamChance, value, 0.0, 100.0);
		g_esSpamAbility[type].g_iSpamCooldown = iGetKeyValue(subsection, MT_SPAM_SECTION, MT_SPAM_SECTION2, MT_SPAM_SECTION3, MT_SPAM_SECTION4, key, "SpamCooldown", "Spam Cooldown", "Spam_Cooldown", "cooldown", g_esSpamAbility[type].g_iSpamCooldown, value, 0, 99999);
		g_esSpamAbility[type].g_iSpamDamage = iGetKeyValue(subsection, MT_SPAM_SECTION, MT_SPAM_SECTION2, MT_SPAM_SECTION3, MT_SPAM_SECTION4, key, "SpamDamage", "Spam Damage", "Spam_Damage", "damage", g_esSpamAbility[type].g_iSpamDamage, value, 0, 99999);
		g_esSpamAbility[type].g_iSpamDuration = iGetKeyValue(subsection, MT_SPAM_SECTION, MT_SPAM_SECTION2, MT_SPAM_SECTION3, MT_SPAM_SECTION4, key, "SpamDuration", "Spam Duration", "Spam_Duration", "duration", g_esSpamAbility[type].g_iSpamDuration, value, 0, 99999);
		g_esSpamAbility[type].g_flSpamInterval = flGetKeyValue(subsection, MT_SPAM_SECTION, MT_SPAM_SECTION2, MT_SPAM_SECTION3, MT_SPAM_SECTION4, key, "SpamInterval", "Spam Interval", "Spam_Interval", "interval", g_esSpamAbility[type].g_flSpamInterval, value, 0.1, 1.0);
		g_esSpamAbility[type].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_SPAM_SECTION, MT_SPAM_SECTION2, MT_SPAM_SECTION3, MT_SPAM_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esSpamAbility[type].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_SPAM_SECTION, MT_SPAM_SECTION2, MT_SPAM_SECTION3, MT_SPAM_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}
}

#if defined MT_ABILITIES_MAIN2
void vSpamSettingsCached(int tank, bool apply, int type)
#else
public void MT_OnSettingsCached(int tank, bool apply, int type)
#endif
{
	bool bHuman = bIsTank(tank, MT_CHECK_FAKECLIENT);
	g_esSpamCache[tank].g_flCloseAreasOnly = flGetSettingValue(apply, bHuman, g_esSpamPlayer[tank].g_flCloseAreasOnly, g_esSpamAbility[type].g_flCloseAreasOnly);
	g_esSpamCache[tank].g_iComboAbility = iGetSettingValue(apply, bHuman, g_esSpamPlayer[tank].g_iComboAbility, g_esSpamAbility[type].g_iComboAbility);
	g_esSpamCache[tank].g_flSpamChance = flGetSettingValue(apply, bHuman, g_esSpamPlayer[tank].g_flSpamChance, g_esSpamAbility[type].g_flSpamChance);
	g_esSpamCache[tank].g_flSpamInterval = flGetSettingValue(apply, bHuman, g_esSpamPlayer[tank].g_flSpamInterval, g_esSpamAbility[type].g_flSpamInterval);
	g_esSpamCache[tank].g_iHumanAbility = iGetSettingValue(apply, bHuman, g_esSpamPlayer[tank].g_iHumanAbility, g_esSpamAbility[type].g_iHumanAbility);
	g_esSpamCache[tank].g_iHumanAmmo = iGetSettingValue(apply, bHuman, g_esSpamPlayer[tank].g_iHumanAmmo, g_esSpamAbility[type].g_iHumanAmmo);
	g_esSpamCache[tank].g_iHumanCooldown = iGetSettingValue(apply, bHuman, g_esSpamPlayer[tank].g_iHumanCooldown, g_esSpamAbility[type].g_iHumanCooldown);
	g_esSpamCache[tank].g_iHumanDuration = iGetSettingValue(apply, bHuman, g_esSpamPlayer[tank].g_iHumanDuration, g_esSpamAbility[type].g_iHumanDuration);
	g_esSpamCache[tank].g_iHumanMode = iGetSettingValue(apply, bHuman, g_esSpamPlayer[tank].g_iHumanMode, g_esSpamAbility[type].g_iHumanMode);
	g_esSpamCache[tank].g_flOpenAreasOnly = flGetSettingValue(apply, bHuman, g_esSpamPlayer[tank].g_flOpenAreasOnly, g_esSpamAbility[type].g_flOpenAreasOnly);
	g_esSpamCache[tank].g_iRequiresHumans = iGetSettingValue(apply, bHuman, g_esSpamPlayer[tank].g_iRequiresHumans, g_esSpamAbility[type].g_iRequiresHumans);
	g_esSpamCache[tank].g_iSpamAbility = iGetSettingValue(apply, bHuman, g_esSpamPlayer[tank].g_iSpamAbility, g_esSpamAbility[type].g_iSpamAbility);
	g_esSpamCache[tank].g_iSpamCooldown = iGetSettingValue(apply, bHuman, g_esSpamPlayer[tank].g_iSpamCooldown, g_esSpamAbility[type].g_iSpamCooldown);
	g_esSpamCache[tank].g_iSpamDamage = iGetSettingValue(apply, bHuman, g_esSpamPlayer[tank].g_iSpamDamage, g_esSpamAbility[type].g_iSpamDamage);
	g_esSpamCache[tank].g_iSpamDuration = iGetSettingValue(apply, bHuman, g_esSpamPlayer[tank].g_iSpamDuration, g_esSpamAbility[type].g_iSpamDuration);
	g_esSpamCache[tank].g_iSpamMessage = iGetSettingValue(apply, bHuman, g_esSpamPlayer[tank].g_iSpamMessage, g_esSpamAbility[type].g_iSpamMessage);
	g_esSpamPlayer[tank].g_iTankType = apply ? type : 0;
}

#if defined MT_ABILITIES_MAIN2
void vSpamCopyStats(int oldTank, int newTank)
#else
public void MT_OnCopyStats(int oldTank, int newTank)
#endif
{
	vSpamCopyStats2(oldTank, newTank);

	if (oldTank != newTank)
	{
		vRemoveSpam(oldTank);
	}
}

#if !defined MT_ABILITIES_MAIN2
public void MT_OnPluginUpdate()
{
	MT_ReloadPlugin(null);
}
#endif

#if defined MT_ABILITIES_MAIN2
void vSpamEventFired(Event event, const char[] name)
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
			vSpamCopyStats2(iBot, iTank);
			vRemoveSpam(iBot);
		}
	}
	else if (StrEqual(name, "player_bot_replace"))
	{
		int iTankId = event.GetInt("player"), iTank = GetClientOfUserId(iTankId),
			iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId);
		if (bIsValidClient(iTank) && bIsTank(iBot))
		{
			vSpamCopyStats2(iTank, iBot);
			vRemoveSpam(iTank);
		}
	}
	else if (StrEqual(name, "player_death") || StrEqual(name, "player_spawn"))
	{
		int iTankId = event.GetInt("userid"), iTank = GetClientOfUserId(iTankId);
		if (MT_IsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME))
		{
			vRemoveSpam(iTank);
		}
	}
	else if (StrEqual(name, "mission_lost") || StrEqual(name, "round_start") || StrEqual(name, "round_end"))
	{
		vSpamReset();
	}
}

#if defined MT_ABILITIES_MAIN2
void vSpamAbilityActivated(int tank)
#else
public void MT_OnAbilityActivated(int tank)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esSpamAbility[g_esSpamPlayer[tank].g_iTankType].g_iAccessFlags, g_esSpamPlayer[tank].g_iAccessFlags)) || g_esSpamCache[tank].g_iHumanAbility == 0))
	{
		return;
	}

	if (MT_IsTankSupported(tank) && (!bIsTank(tank, MT_CHECK_FAKECLIENT) || g_esSpamCache[tank].g_iHumanAbility != 1) && MT_IsCustomTankSupported(tank) && g_esSpamCache[tank].g_iSpamAbility == 1 && g_esSpamCache[tank].g_iComboAbility == 0 && !g_esSpamPlayer[tank].g_bActivated)
	{
		vSpamAbility(tank);
	}
}

#if defined MT_ABILITIES_MAIN2
void vSpamButtonPressed(int tank, int button)
#else
public void MT_OnButtonPressed(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && MT_IsCustomTankSupported(tank))
	{
		if (bIsAreaNarrow(tank, g_esSpamCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esSpamCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esSpamPlayer[tank].g_iTankType) || (g_esSpamCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esSpamCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esSpamAbility[g_esSpamPlayer[tank].g_iTankType].g_iAccessFlags, g_esSpamPlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		if ((button & MT_MAIN_KEY) && g_esSpamCache[tank].g_iSpamAbility == 1 && g_esSpamCache[tank].g_iHumanAbility == 1)
		{
			int iTime = GetTime();
			bool bRecharging = g_esSpamPlayer[tank].g_iCooldown != -1 && g_esSpamPlayer[tank].g_iCooldown > iTime;

			switch (g_esSpamCache[tank].g_iHumanMode)
			{
				case 0:
				{
					if (!g_esSpamPlayer[tank].g_bActivated && !bRecharging)
					{
						vSpamAbility(tank);
					}
					else if (g_esSpamPlayer[tank].g_bActivated)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "SpamHuman3");
					}
					else if (bRecharging)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "SpamHuman4", (g_esSpamPlayer[tank].g_iCooldown - iTime));
					}
				}
				case 1:
				{
					if (g_esSpamPlayer[tank].g_iAmmoCount < g_esSpamCache[tank].g_iHumanAmmo && g_esSpamCache[tank].g_iHumanAmmo > 0)
					{
						if (!g_esSpamPlayer[tank].g_bActivated && !bRecharging)
						{
							g_esSpamPlayer[tank].g_bActivated = true;
							g_esSpamPlayer[tank].g_iAmmoCount++;

							vSpam2(tank);
							MT_PrintToChat(tank, "%s %t", MT_TAG3, "SpamHuman", g_esSpamPlayer[tank].g_iAmmoCount, g_esSpamCache[tank].g_iHumanAmmo);
						}
						else if (g_esSpamPlayer[tank].g_bActivated)
						{
							MT_PrintToChat(tank, "%s %t", MT_TAG3, "SpamHuman3");
						}
						else if (bRecharging)
						{
							MT_PrintToChat(tank, "%s %t", MT_TAG3, "SpamHuman4", (g_esSpamPlayer[tank].g_iCooldown - iTime));
						}
					}
					else
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "SpamAmmo");
					}
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vSpamButtonReleased(int tank, int button)
#else
public void MT_OnButtonReleased(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && g_esSpamCache[tank].g_iHumanAbility == 1)
	{
		if ((button & MT_MAIN_KEY) && g_esSpamCache[tank].g_iHumanMode == 1 && g_esSpamPlayer[tank].g_bActivated && (g_esSpamPlayer[tank].g_iCooldown == -1 || g_esSpamPlayer[tank].g_iCooldown < GetTime()))
		{
			vSpamReset2(tank);
			vSpamReset3(tank);
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vSpamChangeType(int tank, int oldType)
#else
public void MT_OnChangeType(int tank, int oldType, int newType, bool revert)
#endif
{
	if (oldType <= 0)
	{
		return;
	}

	vRemoveSpam(tank);
}

void vSpam(int tank, int pos = -1)
{
	if (g_esSpamPlayer[tank].g_iCooldown != -1 && g_esSpamPlayer[tank].g_iCooldown > GetTime())
	{
		return;
	}

	g_esSpamPlayer[tank].g_bActivated = true;

	vSpam2(tank, pos);

	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esSpamCache[tank].g_iHumanAbility == 1)
	{
		g_esSpamPlayer[tank].g_iAmmoCount++;

		MT_PrintToChat(tank, "%s %t", MT_TAG3, "SpamHuman", g_esSpamPlayer[tank].g_iAmmoCount, g_esSpamCache[tank].g_iHumanAmmo);
	}

	if (g_esSpamCache[tank].g_iSpamMessage == 1)
	{
		char sTankName[33];
		MT_GetTankName(tank, sTankName);
		MT_PrintToChatAll("%s %t", MT_TAG2, "Spam", sTankName);
		MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Spam", LANG_SERVER, sTankName);
	}
}

void vSpam2(int tank, int pos = -1)
{
	if (bIsAreaNarrow(tank, g_esSpamCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esSpamCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esSpamPlayer[tank].g_iTankType) || (g_esSpamCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esSpamCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esSpamAbility[g_esSpamPlayer[tank].g_iTankType].g_iAccessFlags, g_esSpamPlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	char sDamage[11];
	float flDamage = (pos != -1) ? MT_GetCombinationSetting(tank, 3, pos) : float(g_esSpamCache[tank].g_iSpamDamage);
	IntToString(RoundToNearest(MT_GetScaledDamage(flDamage)), sDamage, sizeof sDamage);

	float flPos[3], flAngles[3];
	GetClientEyePosition(tank, flPos);
	GetClientEyeAngles(tank, flAngles);

	int iLauncher = CreateEntityByName("env_rock_launcher");
	if (bIsValidEntity(iLauncher))
	{
		SetEntPropEnt(iLauncher, Prop_Data, "m_hOwnerEntity", tank);
		TeleportEntity(iLauncher, flPos, flAngles);
		DispatchSpawn(iLauncher);
		DispatchKeyValue(iLauncher, "rockdamageoverride", sDamage);
		iLauncher = EntIndexToEntRef(iLauncher);
		g_esSpamPlayer[tank].g_iLauncher = iLauncher;
	}

	float flInterval = (pos != -1) ? MT_GetCombinationSetting(tank, 6, pos) : g_esSpamCache[tank].g_flSpamInterval;
	DataPack dpSpam;
	CreateDataTimer(flInterval, tTimerSpam, dpSpam, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
	dpSpam.WriteCell(iLauncher);
	dpSpam.WriteCell(GetClientUserId(tank));
	dpSpam.WriteCell(g_esSpamPlayer[tank].g_iTankType);
	dpSpam.WriteCell(GetTime());
	dpSpam.WriteCell(pos);
}

void vSpamAbility(int tank)
{
	if ((g_esSpamPlayer[tank].g_iCooldown != -1 && g_esSpamPlayer[tank].g_iCooldown > GetTime()) || bIsAreaNarrow(tank, g_esSpamCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esSpamCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esSpamPlayer[tank].g_iTankType) || (g_esSpamCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esSpamCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esSpamAbility[g_esSpamPlayer[tank].g_iTankType].g_iAccessFlags, g_esSpamPlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (g_esSpamPlayer[tank].g_iAmmoCount < g_esSpamCache[tank].g_iHumanAmmo && g_esSpamCache[tank].g_iHumanAmmo > 0))
	{
		if (MT_GetRandomFloat(0.1, 100.0) <= g_esSpamCache[tank].g_flSpamChance)
		{
			vSpam(tank);
		}
		else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esSpamCache[tank].g_iHumanAbility == 1)
		{
			MT_PrintToChat(tank, "%s %t", MT_TAG3, "SpamHuman2");
		}
	}
	else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esSpamCache[tank].g_iHumanAbility == 1)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "SpamAmmo");
	}
}

void vSpamCopyStats2(int oldTank, int newTank)
{
	g_esSpamPlayer[newTank].g_iAmmoCount = g_esSpamPlayer[oldTank].g_iAmmoCount;
	g_esSpamPlayer[newTank].g_iCooldown = g_esSpamPlayer[oldTank].g_iCooldown;
}

void vRemoveSpamLauncher(int tank)
{
	if (bIsValidEntRef(g_esSpamPlayer[tank].g_iLauncher))
	{
		g_esSpamPlayer[tank].g_iLauncher = EntRefToEntIndex(g_esSpamPlayer[tank].g_iLauncher);
		if (bIsValidEntity(g_esSpamPlayer[tank].g_iLauncher))
		{
			RemoveEntity(g_esSpamPlayer[tank].g_iLauncher);
		}
	}

	g_esSpamPlayer[tank].g_iLauncher = INVALID_ENT_REFERENCE;
}

void vRemoveSpam(int tank)
{
	vRemoveSpamLauncher(tank);

	g_esSpamPlayer[tank].g_bActivated = false;
	g_esSpamPlayer[tank].g_iAmmoCount = 0;
	g_esSpamPlayer[tank].g_iCooldown = -1;
}

void vSpamReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
		{
			vRemoveSpam(iPlayer);
		}
	}
}

void vSpamReset2(int tank)
{
	vRemoveSpamLauncher(tank);

	g_esSpamPlayer[tank].g_bActivated = false;

	if (g_esSpamCache[tank].g_iSpamMessage == 1)
	{
		char sTankName[33];
		MT_GetTankName(tank, sTankName);
		MT_PrintToChatAll("%s %t", MT_TAG2, "Spam2", sTankName);
		MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Spam2", LANG_SERVER, sTankName);
	}
}

void vSpamReset3(int tank)
{
	int iTime = GetTime(), iPos = g_esSpamAbility[g_esSpamPlayer[tank].g_iTankType].g_iComboPosition, iCooldown = (iPos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 2, iPos)) : g_esSpamCache[tank].g_iSpamCooldown;
	iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esSpamCache[tank].g_iHumanAbility == 1 && g_esSpamCache[tank].g_iHumanMode == 0 && g_esSpamPlayer[tank].g_iAmmoCount < g_esSpamCache[tank].g_iHumanAmmo && g_esSpamCache[tank].g_iHumanAmmo > 0) ? g_esSpamCache[tank].g_iHumanCooldown : iCooldown;
	g_esSpamPlayer[tank].g_iCooldown = (iTime + iCooldown);
	if (g_esSpamPlayer[tank].g_iCooldown != -1 && g_esSpamPlayer[tank].g_iCooldown > iTime)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "SpamHuman5", (g_esSpamPlayer[tank].g_iCooldown - iTime));
	}
}

Action tTimerSpamCombo(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esSpamAbility[g_esSpamPlayer[iTank].g_iTankType].g_iAccessFlags, g_esSpamPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esSpamPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esSpamCache[iTank].g_iSpamAbility == 0 || g_esSpamPlayer[iTank].g_bActivated)
	{
		return Plugin_Stop;
	}

	int iPos = pack.ReadCell();
	vSpam(iTank, iPos);

	return Plugin_Continue;
}

Action tTimerSpam(Handle timer, DataPack pack)
{
	pack.Reset();

	int iLauncher = EntRefToEntIndex(pack.ReadCell()), iTank = GetClientOfUserId(pack.ReadCell());
	if (iLauncher == INVALID_ENT_REFERENCE || !bIsValidEntity(iLauncher))
	{
		g_esSpamPlayer[iTank].g_bActivated = false;

		return Plugin_Stop;
	}

	int iType = pack.ReadCell();
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || bIsAreaNarrow(iTank, g_esSpamCache[iTank].g_flOpenAreasOnly) || bIsAreaWide(iTank, g_esSpamCache[iTank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esSpamPlayer[iTank].g_iTankType) || (g_esSpamCache[iTank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esSpamCache[iTank].g_iRequiresHumans) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esSpamAbility[g_esSpamPlayer[iTank].g_iTankType].g_iAccessFlags, g_esSpamPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esSpamPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || iType != g_esSpamPlayer[iTank].g_iTankType || g_esSpamCache[iTank].g_iSpamAbility == 0 || !g_esSpamPlayer[iTank].g_bActivated)
	{
		vSpamReset2(iTank);

		return Plugin_Stop;
	}

	bool bHuman = bIsTank(iTank, MT_CHECK_FAKECLIENT);
	int iTime = pack.ReadCell(), iCurrentTime = GetTime(), iPos = pack.ReadCell(),
		iDuration = (iPos != -1) ? RoundToNearest(MT_GetCombinationSetting(iTank, 5, iPos)) : g_esSpamCache[iTank].g_iSpamDuration;
	iDuration = (bHuman && g_esSpamCache[iTank].g_iHumanAbility == 1) ? g_esSpamCache[iTank].g_iHumanDuration : iDuration;
	if (iDuration > 0 && (!bHuman || (bHuman && g_esSpamCache[iTank].g_iHumanAbility == 1 && g_esSpamCache[iTank].g_iHumanMode == 0)) && (iTime + iDuration) < iCurrentTime)
	{
		vSpamReset2(iTank);
		vSpamReset3(iTank);

		return Plugin_Stop;
	}

	float flPos[3], flAngles[3];
	GetClientEyePosition(iTank, flPos);
	GetClientEyeAngles(iTank, flAngles);
	flPos[2] += 80.0;

	if (bIsValidEntity(iLauncher))
	{
		TeleportEntity(iLauncher, flPos, flAngles);
		AcceptEntityInput(iLauncher, "LaunchRock");
	}

	return Plugin_Continue;
}