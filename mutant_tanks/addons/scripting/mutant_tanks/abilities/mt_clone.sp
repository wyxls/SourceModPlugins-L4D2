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

#define MT_CLONE_COMPILE_METHOD 0 // 0: packaged, 1: standalone

#if !defined MT_ABILITIES_MAIN
	#if MT_CLONE_COMPILE_METHOD == 1
		#include <sourcemod>
		#include <mutant_tanks>
		#include <mt_clone>
	#else
		#error This file must be inside "scripting/mutant_tanks/abilities" while compiling "mt_abilities.sp" to include its content.
	#endif
public Plugin myinfo =
{
	name = "[MT] Clone Ability",
	author = MT_AUTHOR,
	description = "The Mutant Tank creates clones of itself.",
	version = MT_VERSION,
	url = MT_URL
};

bool g_bDedicated;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion evEngine = GetEngineVersion();
	if (evEngine != Engine_Left4Dead && evEngine != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "\"[MT] Clone Ability\" only supports Left 4 Dead 1 & 2.");

		return APLRes_SilentFailure;
	}

	CreateNative("MT_IsCloneSupported", aNative_IsCloneSupported);
	CreateNative("MT_IsTankClone", aNative_IsTankClone);

	RegPluginLibrary("mt_clone");

	g_bDedicated = IsDedicatedServer();

	return APLRes_Success;
}
#else
	#if MT_CLONE_COMPILE_METHOD == 1
		#error This file must be compiled as a standalone plugin.
	#endif
#endif

#define MT_CLONE_SECTION "cloneability"
#define MT_CLONE_SECTION2 "clone ability"
#define MT_CLONE_SECTION3 "clone_ability"
#define MT_CLONE_SECTION4 "clone"

#define MT_MENU_CLONE "Clone Ability"

enum struct esClonePlayer
{
	bool g_bCloned;
	bool g_bFiltered;

	float g_flCloneChance;
	float g_flCloneLifetime;
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;

	int g_iAccessFlags;
	int g_iAmmoCount;
	int g_iCloneAbility;
	int g_iCloneAmount;
	int g_iCloneCooldown;
	int g_iCloneHealth;
	int g_iCloneMaxType;
	int g_iCloneMinType;
	int g_iCloneMessage;
	int g_iCloneMode;
	int g_iCloneRemove;
	int g_iCloneReplace;
	int g_iComboAbility;
	int g_iCooldown;
	int g_iCount;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iOwner;
	int g_iRequiresHumans;
	int g_iTankType;
}

esClonePlayer g_esClonePlayer[MAXPLAYERS + 1];

enum struct esCloneAbility
{
	float g_flCloneChance;
	float g_flCloneLifetime;
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;

	int g_iAccessFlags;
	int g_iCloneAbility;
	int g_iCloneAmount;
	int g_iCloneCooldown;
	int g_iCloneHealth;
	int g_iCloneMaxType;
	int g_iCloneMinType;
	int g_iCloneMessage;
	int g_iCloneMode;
	int g_iCloneRemove;
	int g_iCloneReplace;
	int g_iComboAbility;
	int g_iComboPosition;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iRequiresHumans;
}

esCloneAbility g_esCloneAbility[MT_MAXTYPES + 1];

enum struct esCloneCache
{
	float g_flCloneChance;
	float g_flCloneLifetime;
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;

	int g_iCloneAbility;
	int g_iCloneAmount;
	int g_iCloneCooldown;
	int g_iCloneHealth;
	int g_iCloneMaxType;
	int g_iCloneMinType;
	int g_iCloneMessage;
	int g_iCloneMode;
	int g_iCloneRemove;
	int g_iCloneReplace;
	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iRequiresHumans;
}

esCloneCache g_esCloneCache[MAXPLAYERS + 1];

#if !defined MT_ABILITIES_MAIN
any aNative_IsCloneSupported(Handle plugin, int numParams)
{
	int iTank = GetNativeCell(1);
	if (MT_IsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME) && g_esClonePlayer[iTank].g_bCloned && g_esClonePlayer[iTank].g_bFiltered)
	{
		return false;
	}

	return true;
}

any aNative_IsTankClone(Handle plugin, int numParams)
{
	int iTank = GetNativeCell(1);
	return MT_IsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME) && g_esClonePlayer[iTank].g_bCloned;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");
	LoadTranslations("mutant_tanks_names.phrases");

	RegConsoleCmd("sm_mt_clone", cmdCloneInfo, "View information about the Clone ability.");
}
#endif

#if defined MT_ABILITIES_MAIN
void vCloneMapStart()
#else
public void OnMapStart()
#endif
{
	vCloneReset();
}

#if defined MT_ABILITIES_MAIN
void vCloneClientPutInServer(int client)
#else
public void OnClientPutInServer(int client)
#endif
{
	vRemoveClone(client);
}

#if defined MT_ABILITIES_MAIN
void vCloneClientDisconnect(int client)
#else
public void OnClientDisconnect(int client)
#endif
{
	if (bIsTank(client) && !bIsValidClient(client, MT_CHECK_FAKECLIENT) && g_esClonePlayer[client].g_bCloned)
	{
		g_esClonePlayer[g_esClonePlayer[client].g_iOwner].g_iCount--;
		g_esClonePlayer[client].g_iOwner = 0;

		vRemoveClone(client);
	}
}

#if defined MT_ABILITIES_MAIN
void vCloneClientDisconnect_Post(int client)
#else
public void OnClientDisconnect_Post(int client)
#endif
{
	vRemoveClone(client);
}

#if defined MT_ABILITIES_MAIN
void vCloneMapEnd()
#else
public void OnMapEnd()
#endif
{
	vCloneReset();
}

#if !defined MT_ABILITIES_MAIN
Action cmdCloneInfo(int client, int args)
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
		case false: vCloneMenu(client, MT_CLONE_SECTION4, 0);
	}

	return Plugin_Handled;
}
#endif

void vCloneMenu(int client, const char[] name, int item)
{
	if (StrContains(MT_CLONE_SECTION4, name, false) == -1)
	{
		return;
	}

	Menu mAbilityMenu = new Menu(iCloneMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Clone Ability Information");
	mAbilityMenu.AddItem("Status", "Status");
	mAbilityMenu.AddItem("Ammunition", "Ammunition");
	mAbilityMenu.AddItem("Buttons", "Buttons");
	mAbilityMenu.AddItem("Cooldown", "Cooldown");
	mAbilityMenu.AddItem("Details", "Details");
	mAbilityMenu.AddItem("Human Support", "Human Support");
	mAbilityMenu.DisplayAt(client, item, MENU_TIME_FOREVER);
}

int iCloneMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esCloneCache[param1].g_iCloneAbility == 0) ? "AbilityStatus1" : "AbilityStatus2");
				case 1: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityAmmo", (g_esCloneCache[param1].g_iHumanAmmo - g_esClonePlayer[param1].g_iAmmoCount), g_esCloneCache[param1].g_iHumanAmmo);
				case 2: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityButtons3");
				case 3: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityCooldown", ((g_esCloneCache[param1].g_iHumanAbility == 1) ? g_esCloneCache[param1].g_iHumanCooldown : g_esCloneCache[param1].g_iCloneCooldown));
				case 4: MT_PrintToChat(param1, "%s %t", MT_TAG3, "CloneDetails");
				case 5: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esCloneCache[param1].g_iHumanAbility == 0) ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME))
			{
				vCloneMenu(param1, MT_CLONE_SECTION4, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pClone = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "CloneMenu", param1);
			pClone.SetTitle(sMenuTitle);
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
				}

				return RedrawMenuItem(sMenuOption);
			}
		}
	}

	return 0;
}

#if defined MT_ABILITIES_MAIN
void vCloneDisplayMenu(Menu menu)
#else
public void MT_OnDisplayMenu(Menu menu)
#endif
{
	menu.AddItem(MT_MENU_CLONE, MT_MENU_CLONE);
}

#if defined MT_ABILITIES_MAIN
void vCloneMenuItemSelected(int client, const char[] info)
#else
public void MT_OnMenuItemSelected(int client, const char[] info)
#endif
{
	if (StrEqual(info, MT_MENU_CLONE, false))
	{
		vCloneMenu(client, MT_CLONE_SECTION4, 0);
	}
}

#if defined MT_ABILITIES_MAIN
void vCloneMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#else
public void MT_OnMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#endif
{
	if (StrEqual(info, MT_MENU_CLONE, false))
	{
		FormatEx(buffer, size, "%T", "CloneMenu2", client);
	}
}

#if defined MT_ABILITIES_MAIN
void vClonePluginCheck(ArrayList list)
#else
public void MT_OnPluginCheck(ArrayList list)
#endif
{
	list.PushString(MT_MENU_CLONE);
}

#if defined MT_ABILITIES_MAIN
void vCloneAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#else
public void MT_OnAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#endif
{
	list.PushString(MT_CLONE_SECTION);
	list2.PushString(MT_CLONE_SECTION2);
	list3.PushString(MT_CLONE_SECTION3);
	list4.PushString(MT_CLONE_SECTION4);
}

#if defined MT_ABILITIES_MAIN
void vCloneCombineAbilities(int tank, int type, const float random, const char[] combo)
#else
public void MT_OnCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
#endif
{
	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esCloneCache[tank].g_iHumanAbility != 2)
	{
		g_esCloneAbility[g_esClonePlayer[tank].g_iTankType].g_iComboPosition = -1;

		return;
	}

	g_esCloneAbility[g_esClonePlayer[tank].g_iTankType].g_iComboPosition = -1;

	char sCombo[320], sSet[4][32];
	FormatEx(sCombo, sizeof sCombo, ",%s,", combo);
	FormatEx(sSet[0], sizeof sSet[], ",%s,", MT_CLONE_SECTION);
	FormatEx(sSet[1], sizeof sSet[], ",%s,", MT_CLONE_SECTION2);
	FormatEx(sSet[2], sizeof sSet[], ",%s,", MT_CLONE_SECTION3);
	FormatEx(sSet[3], sizeof sSet[], ",%s,", MT_CLONE_SECTION4);
	if (StrContains(sCombo, sSet[0], false) != -1 || StrContains(sCombo, sSet[1], false) != -1 || StrContains(sCombo, sSet[2], false) != -1 || StrContains(sCombo, sSet[3], false) != -1)
	{
		if (type == MT_COMBO_MAINRANGE && g_esCloneCache[tank].g_iCloneAbility == 1 && g_esCloneCache[tank].g_iComboAbility == 1 && !g_esClonePlayer[tank].g_bCloned)
		{
			char sAbilities[320], sSubset[10][32];
			strcopy(sAbilities, sizeof sAbilities, combo);
			ExplodeString(sAbilities, ",", sSubset, sizeof sSubset, sizeof sSubset[]);

			float flDelay = 0.0;
			for (int iPos = 0; iPos < (sizeof sSubset); iPos++)
			{
				if (StrEqual(sSubset[iPos], MT_CLONE_SECTION, false) || StrEqual(sSubset[iPos], MT_CLONE_SECTION2, false) || StrEqual(sSubset[iPos], MT_CLONE_SECTION3, false) || StrEqual(sSubset[iPos], MT_CLONE_SECTION4, false))
				{
					g_esCloneAbility[g_esClonePlayer[tank].g_iTankType].g_iComboPosition = iPos;

					if (random <= MT_GetCombinationSetting(tank, 1, iPos))
					{
						flDelay = MT_GetCombinationSetting(tank, 4, iPos);

						switch (flDelay)
						{
							case 0.0: vClone(tank);
							default: CreateTimer(flDelay, tTimerCloneCombo, GetClientUserId(tank), TIMER_FLAG_NO_MAPCHANGE);
						}
					}

					break;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vCloneConfigsLoad(int mode)
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
				g_esCloneAbility[iIndex].g_iAccessFlags = 0;
				g_esCloneAbility[iIndex].g_flCloseAreasOnly = 0.0;
				g_esCloneAbility[iIndex].g_iComboAbility = 0;
				g_esCloneAbility[iIndex].g_iComboPosition = -1;
				g_esCloneAbility[iIndex].g_iHumanAbility = 0;
				g_esCloneAbility[iIndex].g_iHumanAmmo = 5;
				g_esCloneAbility[iIndex].g_iHumanCooldown = 0;
				g_esCloneAbility[iIndex].g_flOpenAreasOnly = 0.0;
				g_esCloneAbility[iIndex].g_iRequiresHumans = 0;
				g_esCloneAbility[iIndex].g_iCloneAbility = 0;
				g_esCloneAbility[iIndex].g_iCloneMessage = 0;
				g_esCloneAbility[iIndex].g_iCloneAmount = 2;
				g_esCloneAbility[iIndex].g_flCloneChance = 33.3;
				g_esCloneAbility[iIndex].g_iCloneCooldown = 0;
				g_esCloneAbility[iIndex].g_iCloneHealth = 1000;
				g_esCloneAbility[iIndex].g_flCloneLifetime = 0.0;
				g_esCloneAbility[iIndex].g_iCloneMaxType = 0;
				g_esCloneAbility[iIndex].g_iCloneMinType = 0;
				g_esCloneAbility[iIndex].g_iCloneMode = 0;
				g_esCloneAbility[iIndex].g_iCloneRemove = 1;
				g_esCloneAbility[iIndex].g_iCloneReplace = 1;
			}
		}
		case 3:
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (bIsValidClient(iPlayer))
				{
					g_esClonePlayer[iPlayer].g_iAccessFlags = 0;
					g_esClonePlayer[iPlayer].g_flCloseAreasOnly = 0.0;
					g_esClonePlayer[iPlayer].g_iComboAbility = 0;
					g_esClonePlayer[iPlayer].g_iHumanAbility = 0;
					g_esClonePlayer[iPlayer].g_iHumanAmmo = 0;
					g_esClonePlayer[iPlayer].g_iHumanCooldown = 0;
					g_esClonePlayer[iPlayer].g_flOpenAreasOnly = 0.0;
					g_esClonePlayer[iPlayer].g_iRequiresHumans = 0;
					g_esClonePlayer[iPlayer].g_iCloneAbility = 0;
					g_esClonePlayer[iPlayer].g_iCloneMessage = 0;
					g_esClonePlayer[iPlayer].g_iCloneAmount = 0;
					g_esClonePlayer[iPlayer].g_flCloneChance = 0.0;
					g_esClonePlayer[iPlayer].g_iCloneCooldown = 0;
					g_esClonePlayer[iPlayer].g_iCloneHealth = 0;
					g_esClonePlayer[iPlayer].g_flCloneLifetime = 0.0;
					g_esClonePlayer[iPlayer].g_iCloneMaxType = 0;
					g_esClonePlayer[iPlayer].g_iCloneMinType = 0;
					g_esClonePlayer[iPlayer].g_iCloneMode = 0;
					g_esClonePlayer[iPlayer].g_iCloneRemove = 0;
					g_esClonePlayer[iPlayer].g_iCloneReplace = 0;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vCloneConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#else
public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#endif
{
	if (mode == 3 && bIsValidClient(admin))
	{
		g_esClonePlayer[admin].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_CLONE_SECTION, MT_CLONE_SECTION2, MT_CLONE_SECTION3, MT_CLONE_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esClonePlayer[admin].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esClonePlayer[admin].g_iComboAbility = iGetKeyValue(subsection, MT_CLONE_SECTION, MT_CLONE_SECTION2, MT_CLONE_SECTION3, MT_CLONE_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esClonePlayer[admin].g_iComboAbility, value, 0, 1);
		g_esClonePlayer[admin].g_iHumanAbility = iGetKeyValue(subsection, MT_CLONE_SECTION, MT_CLONE_SECTION2, MT_CLONE_SECTION3, MT_CLONE_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esClonePlayer[admin].g_iHumanAbility, value, 0, 2);
		g_esClonePlayer[admin].g_iHumanAmmo = iGetKeyValue(subsection, MT_CLONE_SECTION, MT_CLONE_SECTION2, MT_CLONE_SECTION3, MT_CLONE_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esClonePlayer[admin].g_iHumanAmmo, value, 0, 99999);
		g_esClonePlayer[admin].g_iHumanCooldown = iGetKeyValue(subsection, MT_CLONE_SECTION, MT_CLONE_SECTION2, MT_CLONE_SECTION3, MT_CLONE_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esClonePlayer[admin].g_iHumanCooldown, value, 0, 99999);
		g_esClonePlayer[admin].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_CLONE_SECTION, MT_CLONE_SECTION2, MT_CLONE_SECTION3, MT_CLONE_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esClonePlayer[admin].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esClonePlayer[admin].g_iRequiresHumans = iGetKeyValue(subsection, MT_CLONE_SECTION, MT_CLONE_SECTION2, MT_CLONE_SECTION3, MT_CLONE_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esClonePlayer[admin].g_iRequiresHumans, value, 0, 32);
		g_esClonePlayer[admin].g_iCloneAbility = iGetKeyValue(subsection, MT_CLONE_SECTION, MT_CLONE_SECTION2, MT_CLONE_SECTION3, MT_CLONE_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esClonePlayer[admin].g_iCloneAbility, value, 0, 1);
		g_esClonePlayer[admin].g_iCloneMessage = iGetKeyValue(subsection, MT_CLONE_SECTION, MT_CLONE_SECTION2, MT_CLONE_SECTION3, MT_CLONE_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esClonePlayer[admin].g_iCloneMessage, value, 0, 1);
		g_esClonePlayer[admin].g_iCloneAmount = iGetKeyValue(subsection, MT_CLONE_SECTION, MT_CLONE_SECTION2, MT_CLONE_SECTION3, MT_CLONE_SECTION4, key, "CloneAmount", "Clone Amount", "Clone_Amount", "amount", g_esClonePlayer[admin].g_iCloneAmount, value, 1, 15);
		g_esClonePlayer[admin].g_flCloneChance = flGetKeyValue(subsection, MT_CLONE_SECTION, MT_CLONE_SECTION2, MT_CLONE_SECTION3, MT_CLONE_SECTION4, key, "CloneChance", "Clone Chance", "Clone_Chance", "chance", g_esClonePlayer[admin].g_flCloneChance, value, 0.0, 100.0);
		g_esClonePlayer[admin].g_iCloneCooldown = iGetKeyValue(subsection, MT_CLONE_SECTION, MT_CLONE_SECTION2, MT_CLONE_SECTION3, MT_CLONE_SECTION4, key, "CloneCooldown", "Clone Cooldown", "Clone_Cooldown", "cooldown", g_esClonePlayer[admin].g_iCloneCooldown, value, 0, 99999);
		g_esClonePlayer[admin].g_iCloneHealth = iGetKeyValue(subsection, MT_CLONE_SECTION, MT_CLONE_SECTION2, MT_CLONE_SECTION3, MT_CLONE_SECTION4, key, "CloneHealth", "Clone Health", "Clone_Health", "health", g_esClonePlayer[admin].g_iCloneHealth, value, 1, MT_MAXHEALTH);
		g_esClonePlayer[admin].g_flCloneLifetime = flGetKeyValue(subsection, MT_CLONE_SECTION, MT_CLONE_SECTION2, MT_CLONE_SECTION3, MT_CLONE_SECTION4, key, "CloneLifetime", "Clone Lifetime", "Clone_Lifetime", "lifetime", g_esClonePlayer[admin].g_flCloneLifetime, value, 0.0, 99999.0);
		g_esClonePlayer[admin].g_iCloneMode = iGetKeyValue(subsection, MT_CLONE_SECTION, MT_CLONE_SECTION2, MT_CLONE_SECTION3, MT_CLONE_SECTION4, key, "CloneMode", "Clone Mode", "Clone_Mode", "mode", g_esClonePlayer[admin].g_iCloneMode, value, 0, 1);
		g_esClonePlayer[admin].g_iCloneRemove = iGetKeyValue(subsection, MT_CLONE_SECTION, MT_CLONE_SECTION2, MT_CLONE_SECTION3, MT_CLONE_SECTION4, key, "CloneRemove", "Clone Remove", "Clone_Remove", "remove", g_esClonePlayer[admin].g_iCloneRemove, value, 0, 1);
		g_esClonePlayer[admin].g_iCloneReplace = iGetKeyValue(subsection, MT_CLONE_SECTION, MT_CLONE_SECTION2, MT_CLONE_SECTION3, MT_CLONE_SECTION4, key, "CloneReplace", "Clone Replace", "Clone_Replace", "replace", g_esClonePlayer[admin].g_iCloneReplace, value, 0, 1);
		g_esClonePlayer[admin].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_CLONE_SECTION, MT_CLONE_SECTION2, MT_CLONE_SECTION3, MT_CLONE_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);

		if (StrEqual(subsection, MT_CLONE_SECTION, false) || StrEqual(subsection, MT_CLONE_SECTION2, false) || StrEqual(subsection, MT_CLONE_SECTION3, false) || StrEqual(subsection, MT_CLONE_SECTION4, false))
		{
			if (StrEqual(key, "CloneType", false) || StrEqual(key, "Clone Type", false) || StrEqual(key, "Clone_Type", false) || StrEqual(key, "type", false))
			{
				char sValue[10], sRange[2][5];
				strcopy(sValue, sizeof sValue, value);
				ReplaceString(sValue, sizeof sValue, " ", "");
				ExplodeString(sValue, "-", sRange, sizeof sRange, sizeof sRange[]);

				g_esClonePlayer[admin].g_iCloneMinType = (sRange[0][0] != '\0') ? iClamp(StringToInt(sRange[0]), 0, MT_MAXTYPES) : g_esClonePlayer[admin].g_iCloneMinType;
				g_esClonePlayer[admin].g_iCloneMaxType = (sRange[1][0] != '\0') ? iClamp(StringToInt(sRange[1]), 0, MT_MAXTYPES) : g_esClonePlayer[admin].g_iCloneMaxType;
			}
		}
	}

	if (mode < 3 && type > 0)
	{
		g_esCloneAbility[type].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_CLONE_SECTION, MT_CLONE_SECTION2, MT_CLONE_SECTION3, MT_CLONE_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esCloneAbility[type].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esCloneAbility[type].g_iComboAbility = iGetKeyValue(subsection, MT_CLONE_SECTION, MT_CLONE_SECTION2, MT_CLONE_SECTION3, MT_CLONE_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esCloneAbility[type].g_iComboAbility, value, 0, 1);
		g_esCloneAbility[type].g_iHumanAbility = iGetKeyValue(subsection, MT_CLONE_SECTION, MT_CLONE_SECTION2, MT_CLONE_SECTION3, MT_CLONE_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esCloneAbility[type].g_iHumanAbility, value, 0, 2);
		g_esCloneAbility[type].g_iHumanAmmo = iGetKeyValue(subsection, MT_CLONE_SECTION, MT_CLONE_SECTION2, MT_CLONE_SECTION3, MT_CLONE_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esCloneAbility[type].g_iHumanAmmo, value, 0, 99999);
		g_esCloneAbility[type].g_iHumanCooldown = iGetKeyValue(subsection, MT_CLONE_SECTION, MT_CLONE_SECTION2, MT_CLONE_SECTION3, MT_CLONE_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esCloneAbility[type].g_iHumanCooldown, value, 0, 99999);
		g_esCloneAbility[type].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_CLONE_SECTION, MT_CLONE_SECTION2, MT_CLONE_SECTION3, MT_CLONE_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esCloneAbility[type].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esCloneAbility[type].g_iRequiresHumans = iGetKeyValue(subsection, MT_CLONE_SECTION, MT_CLONE_SECTION2, MT_CLONE_SECTION3, MT_CLONE_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esCloneAbility[type].g_iRequiresHumans, value, 0, 32);
		g_esCloneAbility[type].g_iCloneAbility = iGetKeyValue(subsection, MT_CLONE_SECTION, MT_CLONE_SECTION2, MT_CLONE_SECTION3, MT_CLONE_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esCloneAbility[type].g_iCloneAbility, value, 0, 1);
		g_esCloneAbility[type].g_iCloneMessage = iGetKeyValue(subsection, MT_CLONE_SECTION, MT_CLONE_SECTION2, MT_CLONE_SECTION3, MT_CLONE_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esCloneAbility[type].g_iCloneMessage, value, 0, 1);
		g_esCloneAbility[type].g_iCloneAmount = iGetKeyValue(subsection, MT_CLONE_SECTION, MT_CLONE_SECTION2, MT_CLONE_SECTION3, MT_CLONE_SECTION4, key, "CloneAmount", "Clone Amount", "Clone_Amount", "amount", g_esCloneAbility[type].g_iCloneAmount, value, 1, 15);
		g_esCloneAbility[type].g_flCloneChance = flGetKeyValue(subsection, MT_CLONE_SECTION, MT_CLONE_SECTION2, MT_CLONE_SECTION3, MT_CLONE_SECTION4, key, "CloneChance", "Clone Chance", "Clone_Chance", "chance", g_esCloneAbility[type].g_flCloneChance, value, 0.0, 100.0);
		g_esCloneAbility[type].g_iCloneCooldown = iGetKeyValue(subsection, MT_CLONE_SECTION, MT_CLONE_SECTION2, MT_CLONE_SECTION3, MT_CLONE_SECTION4, key, "CloneCooldown", "Clone Cooldown", "Clone_Cooldown", "cooldown", g_esCloneAbility[type].g_iCloneCooldown, value, 0, 99999);
		g_esCloneAbility[type].g_iCloneHealth = iGetKeyValue(subsection, MT_CLONE_SECTION, MT_CLONE_SECTION2, MT_CLONE_SECTION3, MT_CLONE_SECTION4, key, "CloneHealth", "Clone Health", "Clone_Health", "health", g_esCloneAbility[type].g_iCloneHealth, value, 1, MT_MAXHEALTH);
		g_esCloneAbility[type].g_flCloneLifetime = flGetKeyValue(subsection, MT_CLONE_SECTION, MT_CLONE_SECTION2, MT_CLONE_SECTION3, MT_CLONE_SECTION4, key, "CloneLifetime", "Clone Lifetime", "Clone_Lifetime", "lifetime", g_esCloneAbility[type].g_flCloneLifetime, value, 0.0, 99999.0);
		g_esCloneAbility[type].g_iCloneMode = iGetKeyValue(subsection, MT_CLONE_SECTION, MT_CLONE_SECTION2, MT_CLONE_SECTION3, MT_CLONE_SECTION4, key, "CloneMode", "Clone Mode", "Clone_Mode", "mode", g_esCloneAbility[type].g_iCloneMode, value, 0, 1);
		g_esCloneAbility[type].g_iCloneRemove = iGetKeyValue(subsection, MT_CLONE_SECTION, MT_CLONE_SECTION2, MT_CLONE_SECTION3, MT_CLONE_SECTION4, key, "CloneRemove", "Clone Remove", "Clone_Remove", "remove", g_esCloneAbility[type].g_iCloneRemove, value, 0, 1);
		g_esCloneAbility[type].g_iCloneReplace = iGetKeyValue(subsection, MT_CLONE_SECTION, MT_CLONE_SECTION2, MT_CLONE_SECTION3, MT_CLONE_SECTION4, key, "CloneReplace", "Clone Replace", "Clone_Replace", "replace", g_esCloneAbility[type].g_iCloneReplace, value, 0, 1);
		g_esCloneAbility[type].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_CLONE_SECTION, MT_CLONE_SECTION2, MT_CLONE_SECTION3, MT_CLONE_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);

		if (StrEqual(subsection, MT_CLONE_SECTION, false) || StrEqual(subsection, MT_CLONE_SECTION2, false) || StrEqual(subsection, MT_CLONE_SECTION3, false) || StrEqual(subsection, MT_CLONE_SECTION4, false))
		{
			if (StrEqual(key, "CloneType", false) || StrEqual(key, "Clone Type", false) || StrEqual(key, "Clone_Type", false) || StrEqual(key, "type", false))
			{
				char sValue[10], sRange[2][5];
				strcopy(sValue, sizeof sValue, value);
				ReplaceString(sValue, sizeof sValue, " ", "");
				ExplodeString(sValue, "-", sRange, sizeof sRange, sizeof sRange[]);

				g_esCloneAbility[type].g_iCloneMinType = (sRange[0][0] != '\0') ? iClamp(StringToInt(sRange[0]), 0, MT_MAXTYPES) : g_esCloneAbility[type].g_iCloneMinType;
				g_esCloneAbility[type].g_iCloneMaxType = (sRange[1][0] != '\0') ? iClamp(StringToInt(sRange[1]), 0, MT_MAXTYPES) : g_esCloneAbility[type].g_iCloneMaxType;
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vCloneSettingsCached(int tank, bool apply, int type)
#else
public void MT_OnSettingsCached(int tank, bool apply, int type)
#endif
{
	bool bHuman = bIsTank(tank, MT_CHECK_FAKECLIENT);
	g_esCloneCache[tank].g_flCloneChance = flGetSettingValue(apply, bHuman, g_esClonePlayer[tank].g_flCloneChance, g_esCloneAbility[type].g_flCloneChance);
	g_esCloneCache[tank].g_flCloneLifetime = flGetSettingValue(apply, bHuman, g_esClonePlayer[tank].g_flCloneLifetime, g_esCloneAbility[type].g_flCloneLifetime);
	g_esCloneCache[tank].g_iCloneAbility = iGetSettingValue(apply, bHuman, g_esClonePlayer[tank].g_iCloneAbility, g_esCloneAbility[type].g_iCloneAbility);
	g_esCloneCache[tank].g_iCloneAmount = iGetSettingValue(apply, bHuman, g_esClonePlayer[tank].g_iCloneAmount, g_esCloneAbility[type].g_iCloneAmount);
	g_esCloneCache[tank].g_iCloneCooldown = iGetSettingValue(apply, bHuman, g_esClonePlayer[tank].g_iCloneCooldown, g_esCloneAbility[type].g_iCloneCooldown);
	g_esCloneCache[tank].g_iCloneHealth = iGetSettingValue(apply, bHuman, g_esClonePlayer[tank].g_iCloneHealth, g_esCloneAbility[type].g_iCloneHealth);
	g_esCloneCache[tank].g_iCloneMaxType = iGetSettingValue(apply, bHuman, g_esClonePlayer[tank].g_iCloneMaxType, g_esCloneAbility[type].g_iCloneMaxType);
	g_esCloneCache[tank].g_iCloneMinType = iGetSettingValue(apply, bHuman, g_esClonePlayer[tank].g_iCloneMinType, g_esCloneAbility[type].g_iCloneMinType);
	g_esCloneCache[tank].g_iCloneMessage = iGetSettingValue(apply, bHuman, g_esClonePlayer[tank].g_iCloneMessage, g_esCloneAbility[type].g_iCloneMessage);
	g_esCloneCache[tank].g_iCloneMode = iGetSettingValue(apply, bHuman, g_esClonePlayer[tank].g_iCloneMode, g_esCloneAbility[type].g_iCloneMode);
	g_esCloneCache[tank].g_iCloneRemove = iGetSettingValue(apply, bHuman, g_esClonePlayer[tank].g_iCloneRemove, g_esCloneAbility[type].g_iCloneRemove);
	g_esCloneCache[tank].g_iCloneReplace = iGetSettingValue(apply, bHuman, g_esClonePlayer[tank].g_iCloneReplace, g_esCloneAbility[type].g_iCloneReplace);
	g_esCloneCache[tank].g_flCloseAreasOnly = flGetSettingValue(apply, bHuman, g_esClonePlayer[tank].g_flCloseAreasOnly, g_esCloneAbility[type].g_flCloseAreasOnly);
	g_esCloneCache[tank].g_iComboAbility = iGetSettingValue(apply, bHuman, g_esClonePlayer[tank].g_iComboAbility, g_esCloneAbility[type].g_iComboAbility);
	g_esCloneCache[tank].g_iHumanAbility = iGetSettingValue(apply, bHuman, g_esClonePlayer[tank].g_iHumanAbility, g_esCloneAbility[type].g_iHumanAbility);
	g_esCloneCache[tank].g_iHumanAmmo = iGetSettingValue(apply, bHuman, g_esClonePlayer[tank].g_iHumanAmmo, g_esCloneAbility[type].g_iHumanAmmo);
	g_esCloneCache[tank].g_iHumanCooldown = iGetSettingValue(apply, bHuman, g_esClonePlayer[tank].g_iHumanCooldown, g_esCloneAbility[type].g_iHumanCooldown);
	g_esCloneCache[tank].g_flOpenAreasOnly = flGetSettingValue(apply, bHuman, g_esClonePlayer[tank].g_flOpenAreasOnly, g_esCloneAbility[type].g_flOpenAreasOnly);
	g_esCloneCache[tank].g_iRequiresHumans = iGetSettingValue(apply, bHuman, g_esClonePlayer[tank].g_iRequiresHumans, g_esCloneAbility[type].g_iRequiresHumans);
	g_esClonePlayer[tank].g_iTankType = apply ? type : 0;
}

#if defined MT_ABILITIES_MAIN
void vCloneCopyStats(int oldTank, int newTank)
#else
public void MT_OnCopyStats(int oldTank, int newTank)
#endif
{
	vCloneCopyStats2(oldTank, newTank);

	if (oldTank != newTank)
	{
		vRemoveClone(oldTank);
	}
}

#if !defined MT_ABILITIES_MAIN
public void MT_OnPluginUpdate()
{
	MT_ReloadPlugin(null);
}
#endif

#if defined MT_ABILITIES_MAIN
void vClonePluginEnd()
#else
public void MT_OnPluginEnd()
#endif
{
	for (int iClone = 1; iClone <= MaxClients; iClone++)
	{
		if (bIsTank(iClone, MT_CHECK_INGAME|MT_CHECK_ALIVE) && g_esClonePlayer[iClone].g_bCloned)
		{
			ForcePlayerSuicide(iClone);
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vCloneEventFired(Event event, const char[] name)
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
			vCloneCopyStats2(iBot, iTank);
			vRemoveClone(iBot);
		}
	}
	else if (StrEqual(name, "player_bot_replace"))
	{
		int iTankId = event.GetInt("player"), iTank = GetClientOfUserId(iTankId),
			iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId);
		if (bIsValidClient(iTank) && bIsTank(iBot))
		{
			vCloneCopyStats2(iTank, iBot);
			vRemoveClone(iTank);
		}
	}
	else if (StrEqual(name, "player_death"))
	{
		int iTankId = event.GetInt("userid"), iTank = GetClientOfUserId(iTankId);
		if (MT_IsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME))
		{
			switch (g_esClonePlayer[iTank].g_bCloned)
			{
				case true:
				{
					int iTime = 0, iPos = -1, iCooldown = -1;
					for (int iOwner = 1; iOwner <= MaxClients; iOwner++)
					{
						if (MT_IsTankSupported(iOwner, MT_CHECK_INGAME|MT_CHECK_ALIVE) && g_esClonePlayer[iTank].g_iOwner == iOwner)
						{
							g_esClonePlayer[iTank].g_bCloned = false;
							g_esClonePlayer[iTank].g_iOwner = 0;

							if (g_esCloneCache[iOwner].g_iCloneAbility == 1)
							{
								switch (g_esClonePlayer[iOwner].g_iCount)
								{
									case 0, 1:
									{
										g_esClonePlayer[iOwner].g_iCount = (g_esCloneCache[iOwner].g_iCloneReplace == 1) ? 0 : g_esClonePlayer[iOwner].g_iCount;

										iTime = GetTime();
										if (g_esClonePlayer[iOwner].g_iCooldown == -1 || g_esClonePlayer[iOwner].g_iCooldown < iTime)
										{
											iPos = g_esCloneAbility[g_esClonePlayer[iOwner].g_iTankType].g_iComboPosition;
											iCooldown = (iPos != -1) ? RoundToNearest(MT_GetCombinationSetting(iOwner, 2, iPos)) : g_esCloneCache[iOwner].g_iCloneCooldown;
											iCooldown = (bIsTank(iOwner, MT_CHECK_FAKECLIENT) && g_esCloneCache[iOwner].g_iHumanAbility == 1 && g_esClonePlayer[iOwner].g_iAmmoCount < g_esCloneCache[iOwner].g_iHumanAmmo && g_esCloneCache[iOwner].g_iHumanAmmo > 0) ? g_esCloneCache[iOwner].g_iHumanCooldown : iCooldown;
											g_esClonePlayer[iOwner].g_iCooldown = (iTime + iCooldown);
											if (g_esClonePlayer[iOwner].g_iCooldown != -1 && g_esClonePlayer[iOwner].g_iCooldown > iTime)
											{
												MT_PrintToChat(iOwner, "%s %t", MT_TAG3, "CloneHuman6", (g_esClonePlayer[iOwner].g_iCooldown - iTime));
											}
										}
									}
									default:
									{
										if (g_esCloneCache[iOwner].g_iCloneReplace == 1)
										{
											g_esClonePlayer[iOwner].g_iCount--;
										}

										if (bIsTank(iOwner, MT_CHECK_FAKECLIENT) && g_esCloneCache[iOwner].g_iHumanAbility == 1)
										{
											MT_PrintToChat(iOwner, "%s %t", MT_TAG3, "CloneHuman5");
										}
									}
								}
							}

							break;
						}
					}
				}
				case false: vRemoveClones(iTank);
			}

			vRemoveClone(iTank);
		}
	}
	else if (StrEqual(name, "mission_lost") || StrEqual(name, "round_start") || StrEqual(name, "round_end"))
	{
		vCloneReset();
	}
}

#if defined MT_ABILITIES_MAIN
void vCloneAbilityActivated(int tank)
#else
public void MT_OnAbilityActivated(int tank)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esCloneAbility[g_esClonePlayer[tank].g_iTankType].g_iAccessFlags, g_esClonePlayer[tank].g_iAccessFlags)) || g_esCloneCache[tank].g_iHumanAbility == 0))
	{
		return;
	}

	if (MT_IsTankSupported(tank) && (!bIsTank(tank, MT_CHECK_FAKECLIENT) || g_esCloneCache[tank].g_iHumanAbility != 1) && g_esCloneCache[tank].g_iCloneAbility == 1 && g_esCloneCache[tank].g_iComboAbility == 0 && (g_esClonePlayer[tank].g_iCooldown == -1 || g_esClonePlayer[tank].g_iCooldown < GetTime()) && !g_esClonePlayer[tank].g_bCloned)
	{
		vCloneAbility(tank);
	}
}

#if defined MT_ABILITIES_MAIN
void vCloneButtonPressed(int tank, int button)
#else
public void MT_OnButtonPressed(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT))
	{
		if (bIsAreaNarrow(tank, g_esCloneCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esCloneCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esClonePlayer[tank].g_iTankType) || (g_esCloneCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esCloneCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esCloneAbility[g_esClonePlayer[tank].g_iTankType].g_iAccessFlags, g_esClonePlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		if ((button & MT_SPECIAL_KEY) && g_esCloneCache[tank].g_iCloneAbility == 1 && g_esCloneCache[tank].g_iHumanAbility == 1)
		{
			int iTime = GetTime();
			bool bRecharging = g_esClonePlayer[tank].g_iCooldown != -1 && g_esClonePlayer[tank].g_iCooldown > iTime;
			if (!g_esClonePlayer[tank].g_bCloned && !bRecharging)
			{
				vCloneAbility(tank);
			}
			else if (g_esClonePlayer[tank].g_bCloned)
			{
				MT_PrintToChat(tank, "%s %t", MT_TAG3, "CloneHuman3");
			}
			else if (bRecharging)
			{
				MT_PrintToChat(tank, "%s %t", MT_TAG3, "CloneHuman4", (g_esClonePlayer[tank].g_iCooldown - iTime));
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vCloneChangeType(int tank, int oldType, bool revert)
#else
public void MT_OnChangeType(int tank, int oldType, int newType, bool revert)
#endif
{
	if (oldType <= 0)
	{
		return;
	}

	vRemoveClones(tank);
	vRemoveClone(tank, revert);
}

void vClone(int tank)
{
	if (g_esClonePlayer[tank].g_iCooldown != -1 && g_esClonePlayer[tank].g_iCooldown > GetTime())
	{
		return;
	}

	if (!g_esClonePlayer[tank].g_bCloned && g_esClonePlayer[tank].g_iCount < g_esCloneCache[tank].g_iCloneAmount)
	{
		float flHitPos[3], flPos[3], flAngles[3], flVector[3];
		GetClientEyePosition(tank, flPos);
		GetClientEyeAngles(tank, flAngles);
		flAngles[0] = -25.0;

		GetAngleVectors(flAngles, flAngles, NULL_VECTOR, NULL_VECTOR);
		NormalizeVector(flAngles, flAngles);
		ScaleVector(flAngles, -1.0);
		vCopyVector(flAngles, flVector);
		GetVectorAngles(flAngles, flAngles);

		Handle hTrace = TR_TraceRayFilterEx(flPos, flAngles, MASK_SOLID, RayType_Infinite, bTraceRayDontHitSelf, tank);
		if (hTrace != null)
		{
			if (TR_DidHit(hTrace))
			{
				TR_GetEndPosition(flHitPos, hTrace);
				NormalizeVector(flVector, flVector);
				ScaleVector(flVector, -40.0);
				AddVectors(flHitPos, flVector, flHitPos);
				if (40.0 < GetVectorDistance(flHitPos, flPos) < 200.0)
				{
					bool[] bExists = new bool[MaxClients + 1];
					for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
					{
						bExists[iPlayer] = false;
						if (bIsTank(iPlayer, MT_CHECK_INGAME))
						{
							bExists[iPlayer] = true;
						}
					}

					switch (g_esCloneCache[tank].g_iCloneMinType == 0 || g_esCloneCache[tank].g_iCloneMaxType == 0)
					{
						case true: vClone2(tank);
						case false: vClone2(tank, g_esCloneCache[tank].g_iCloneMinType, g_esCloneCache[tank].g_iCloneMaxType);
					}

					int iTank = 0;
					for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
					{
						if (bIsTank(iPlayer, MT_CHECK_INGAME|MT_CHECK_ALIVE) && !bExists[iPlayer])
						{
							iTank = iPlayer;

							break;
						}
					}

					if (bIsTank(iTank))
					{
						TeleportEntity(iTank, flHitPos);

						g_esClonePlayer[iTank].g_bCloned = true;
						g_esClonePlayer[iTank].g_iOwner = tank;
						g_esClonePlayer[tank].g_iCount++;

						if (g_esCloneCache[tank].g_iCloneMode == 0)
						{
							g_esClonePlayer[iTank].g_bFiltered = true;
						}

						if (g_esCloneCache[tank].g_flCloneLifetime > 0.0)
						{
							CreateTimer(g_esCloneCache[tank].g_flCloneLifetime, tTimerKillClone, GetClientUserId(iTank), TIMER_FLAG_NO_MAPCHANGE);
						}

						int iNewHealth = (g_esCloneCache[tank].g_iCloneHealth > MT_MAXHEALTH) ? MT_MAXHEALTH : g_esCloneCache[tank].g_iCloneHealth;
						SetEntProp(iTank, Prop_Data, "m_iHealth", iNewHealth);
						SetEntProp(iTank, Prop_Data, "m_iMaxHealth", iNewHealth);

						if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esCloneCache[tank].g_iHumanAbility == 1)
						{
							g_esClonePlayer[tank].g_iAmmoCount++;

							MT_PrintToChat(tank, "%s %t", MT_TAG3, "CloneHuman", g_esClonePlayer[tank].g_iAmmoCount, g_esCloneCache[tank].g_iHumanAmmo);
						}

						if (g_esCloneCache[tank].g_iCloneMessage == 1)
						{
							char sTankName[33];
							MT_GetTankName(tank, sTankName);
							MT_PrintToChatAll("%s %t", MT_TAG2, "Clone", sTankName);
							MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Clone", LANG_SERVER, sTankName);
						}
					}
				}
			}

			delete hTrace;
		}
	}
}

void vClone2(int tank, int min = 0, int max = 0)
{
	if (bIsAreaNarrow(tank, g_esCloneCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esCloneCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esClonePlayer[tank].g_iTankType) || (g_esCloneCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esCloneCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esCloneAbility[g_esClonePlayer[tank].g_iTankType].g_iAccessFlags, g_esClonePlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	int iMin = (min > 0) ? min : MT_GetMinType(),
		iMax = (max > 0) ? max : MT_GetMaxType(),
		iTypeCount = 0, iTankTypes[MT_MAXTYPES + 1];
	for (int iIndex = iMin; iIndex <= iMax; iIndex++)
	{
		if (!MT_IsTypeEnabled(iIndex) || !MT_CanTypeSpawn(iIndex) || MT_DoesTypeRequireHumans(iIndex))
		{
			continue;
		}

		iTankTypes[iTypeCount + 1] = iIndex;
		iTypeCount++;
	}

	int iType = (iTypeCount > 0) ? iTankTypes[MT_GetRandomInt(1, iTypeCount)] : g_esClonePlayer[tank].g_iTankType;
	MT_SpawnTank(tank, iType);
}

void vCloneAbility(int tank)
{
	if ((g_esClonePlayer[tank].g_iCooldown != -1 && g_esClonePlayer[tank].g_iCooldown > GetTime()) || bIsAreaNarrow(tank, g_esCloneCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esCloneCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esClonePlayer[tank].g_iTankType) || (g_esCloneCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esCloneCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esCloneAbility[g_esClonePlayer[tank].g_iTankType].g_iAccessFlags, g_esClonePlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	if (g_esClonePlayer[tank].g_iCount < g_esCloneCache[tank].g_iCloneAmount && (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (g_esClonePlayer[tank].g_iAmmoCount < g_esCloneCache[tank].g_iHumanAmmo && g_esCloneCache[tank].g_iHumanAmmo > 0)))
	{
		if (MT_GetRandomFloat(0.1, 100.0) <= g_esCloneCache[tank].g_flCloneChance)
		{
			vClone(tank);
		}
		else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esCloneCache[tank].g_iHumanAbility == 1)
		{
			MT_PrintToChat(tank, "%s %t", MT_TAG3, "CloneHuman2");
		}
	}
	else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esCloneCache[tank].g_iHumanAbility == 1)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "CloneAmmo");
	}
}

void vCloneCopyStats2(int oldTank, int newTank)
{
	g_esClonePlayer[newTank].g_bCloned = g_esClonePlayer[oldTank].g_bCloned;
	g_esClonePlayer[newTank].g_bFiltered = g_esClonePlayer[oldTank].g_bFiltered;
	g_esClonePlayer[newTank].g_iAmmoCount = g_esClonePlayer[oldTank].g_iAmmoCount;
	g_esClonePlayer[newTank].g_iCooldown = g_esClonePlayer[oldTank].g_iCooldown;
	g_esClonePlayer[newTank].g_iCount = g_esClonePlayer[oldTank].g_iCount;
}

void vRemoveClone(int tank, int level = 2)
{
	if (level == 2)
	{
		g_esClonePlayer[tank].g_bCloned = false;
	}

	if (level > 0)
	{
		g_esClonePlayer[tank].g_bFiltered = false;
	}

	g_esClonePlayer[tank].g_iAmmoCount = 0;
	g_esClonePlayer[tank].g_iCount = 0;
	g_esClonePlayer[tank].g_iCooldown = -1;
}

void vRemoveClones(int tank)
{
	if (!g_esClonePlayer[tank].g_bCloned && g_esCloneCache[tank].g_iCloneRemove == 1)
	{
		for (int iClone = 1; iClone <= MaxClients; iClone++)
		{
			if (g_esClonePlayer[iClone].g_iOwner == tank)
			{
				g_esClonePlayer[iClone].g_iOwner = 0;

				if (g_esClonePlayer[iClone].g_bCloned && bIsValidClient(iClone, MT_CHECK_INGAME|MT_CHECK_ALIVE))
				{
					ForcePlayerSuicide(iClone);
				}
			}
		}
	}
}

void vCloneReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
		{
			vRemoveClone(iPlayer);

			g_esClonePlayer[iPlayer].g_iOwner = 0;
		}
	}
}

Action tTimerCloneCombo(Handle timer, int userid)
{
	int iTank = GetClientOfUserId(userid);
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esCloneAbility[g_esClonePlayer[iTank].g_iTankType].g_iAccessFlags, g_esClonePlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esClonePlayer[iTank].g_iTankType) || g_esClonePlayer[iTank].g_bCloned || g_esCloneCache[iTank].g_iCloneAbility == 0)
	{
		return Plugin_Stop;
	}

	vClone(iTank);

	return Plugin_Continue;
}

Action tTimerKillClone(Handle timer, int userid)
{
	int iTank = GetClientOfUserId(userid);
	if (!MT_IsTankSupported(iTank) || !g_esClonePlayer[iTank].g_bCloned)
	{
		return Plugin_Stop;
	}

	ForcePlayerSuicide(iTank);

	return Plugin_Continue;
}