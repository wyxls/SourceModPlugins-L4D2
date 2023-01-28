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

#define MT_ITEM_COMPILE_METHOD 0 // 0: packaged, 1: standalone

#if !defined MT_ABILITIES_MAIN
	#if MT_ITEM_COMPILE_METHOD == 1
		#include <sourcemod>
		#include <mutant_tanks>
	#else
		#error This file must be inside "scripting/mutant_tanks/abilities" while compiling "mt_abilities.sp" to include its content.
	#endif
public Plugin myinfo =
{
	name = "[MT] Item Ability",
	author = MT_AUTHOR,
	description = "The Mutant Tank gives survivors items upon death.",
	version = MT_VERSION,
	url = MT_URL
};

bool g_bDedicated;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion evEngine = GetEngineVersion();
	if (evEngine != Engine_Left4Dead && evEngine != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "\"[MT] Item Ability\" only supports Left 4 Dead 1 & 2.");

		return APLRes_SilentFailure;
	}

	g_bDedicated = IsDedicatedServer();

	return APLRes_Success;
}
#else
	#if MT_ITEM_COMPILE_METHOD == 1
		#error This file must be compiled as a standalone plugin.
	#endif
#endif

#define MT_ITEM_SECTION "itemability"
#define MT_ITEM_SECTION2 "item ability"
#define MT_ITEM_SECTION3 "item_ability"
#define MT_ITEM_SECTION4 "item"

#define MT_MENU_ITEM "Item Ability"

#define MODEL_FIREWORKCRATE "models/props_junk/explosive_box001.mdl" // Only available in L4D2
#define MODEL_OXYGENTANK "models/props_equipment/oxygentank01.mdl"
#define MODEL_PROPANETANK "models/props_junk/propanecanister001a.mdl"

enum struct esItemPlayer
{
	bool g_bActivated;

	char g_sItemLoadout[325];
	char g_sItemPinata[325];

	float g_flCloseAreasOnly;
	float g_flItemChance;
	float g_flItemPinataChance;
	float g_flOpenAreasOnly;

	int g_iAccessFlags;
	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iImmunityFlags;
	int g_iItemAbility;
	int g_iItemMessage;
	int g_iItemMode;
	int g_iItemPinataBody;
	int g_iRequiresHumans;
	int g_iTankType;
}

esItemPlayer g_esItemPlayer[MAXPLAYERS + 1];

enum struct esItemAbility
{
	char g_sItemLoadout[325];
	char g_sItemPinata[325];

	float g_flCloseAreasOnly;
	float g_flItemChance;
	float g_flItemPinataChance;
	float g_flOpenAreasOnly;

	int g_iAccessFlags;
	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iImmunityFlags;
	int g_iItemAbility;
	int g_iItemMessage;
	int g_iItemMode;
	int g_iItemPinataBody;
	int g_iRequiresHumans;
}

esItemAbility g_esItemAbility[MT_MAXTYPES + 1];

enum struct esItemCache
{
	char g_sItemLoadout[325];
	char g_sItemPinata[325];

	float g_flCloseAreasOnly;
	float g_flItemChance;
	float g_flItemPinataChance;
	float g_flOpenAreasOnly;

	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iItemAbility;
	int g_iItemMessage;
	int g_iItemMode;
	int g_iItemPinataBody;
	int g_iRequiresHumans;
}

esItemCache g_esItemCache[MAXPLAYERS + 1];

int g_iItemDeathModelOwner = 0;

#if !defined MT_ABILITIES_MAIN
public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");
	LoadTranslations("mutant_tanks_names.phrases");

	RegConsoleCmd("sm_mt_item", cmdItemInfo, "View information about the Item ability.");
}
#endif

#if defined MT_ABILITIES_MAIN
void vItemMapStart()
#else
public void OnMapStart()
#endif
{
	vItemReset();
}

#if defined MT_ABILITIES_MAIN
void vItemClientPutInServer(int client)
#else
public void OnClientPutInServer(int client)
#endif
{
	g_esItemPlayer[client].g_bActivated = false;
}

#if defined MT_ABILITIES_MAIN
void vItemClientDisconnect_Post(int client)
#else
public void OnClientDisconnect_Post(int client)
#endif
{
	g_esItemPlayer[client].g_bActivated = false;
}

#if defined MT_ABILITIES_MAIN
void vItemMapEnd()
#else
public void OnMapEnd()
#endif
{
	vItemReset();
}

#if !defined MT_ABILITIES_MAIN
Action cmdItemInfo(int client, int args)
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
		case false: vItemMenu(client, MT_ITEM_SECTION4, 0);
	}

	return Plugin_Handled;
}
#endif

void vItemMenu(int client, const char[] name, int item)
{
	if (StrContains(MT_ITEM_SECTION4, name, false) == -1)
	{
		return;
	}

	Menu mAbilityMenu = new Menu(iItemMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Item Ability Information");
	mAbilityMenu.AddItem("Status", "Status");
	mAbilityMenu.AddItem("Buttons", "Buttons");
	mAbilityMenu.AddItem("Details", "Details");
	mAbilityMenu.AddItem("Human Support", "Human Support");
	mAbilityMenu.DisplayAt(client, item, MENU_TIME_FOREVER);
}

int iItemMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esItemCache[param1].g_iItemAbility == 0) ? "AbilityStatus1" : "AbilityStatus2");
				case 1: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityButtons4");
				case 2: MT_PrintToChat(param1, "%s %t", MT_TAG3, "ItemDetails");
				case 3: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esItemCache[param1].g_iHumanAbility == 0) ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME))
			{
				vItemMenu(param1, MT_ITEM_SECTION4, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pItem = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "ItemMenu", param1);
			pItem.SetTitle(sMenuTitle);
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
void vItemDisplayMenu(Menu menu)
#else
public void MT_OnDisplayMenu(Menu menu)
#endif
{
	menu.AddItem(MT_MENU_ITEM, MT_MENU_ITEM);
}

#if defined MT_ABILITIES_MAIN
void vItemMenuItemSelected(int client, const char[] info)
#else
public void MT_OnMenuItemSelected(int client, const char[] info)
#endif
{
	if (StrEqual(info, MT_MENU_ITEM, false))
	{
		vItemMenu(client, MT_ITEM_SECTION4, 0);
	}
}

#if defined MT_ABILITIES_MAIN
void vItemMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#else
public void MT_OnMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#endif
{
	if (StrEqual(info, MT_MENU_ITEM, false))
	{
		FormatEx(buffer, size, "%T", "ItemMenu2", client);
	}
}

#if defined MT_ABILITIES_MAIN
void vItemEntityCreated(int entity, const char[] classname)
#else
public void OnEntityCreated(int entity, const char[] classname)
#endif
{
	if (bIsValidEntity(entity) && StrEqual(classname, "survivor_death_model"))
	{
		int iOwner = GetClientOfUserId(g_iItemDeathModelOwner);
		if (bIsValidClient(iOwner))
		{
			SDKHook(entity, SDKHook_SpawnPost, OnItemModelSpawnPost);
		}

		g_iItemDeathModelOwner = 0;
	}
}

void OnItemModelSpawnPost(int model)
{
	g_iItemDeathModelOwner = 0;

	SDKUnhook(model, SDKHook_SpawnPost, OnItemModelSpawnPost);

	if (!bIsValidEntity(model))
	{
		return;
	}

	RemoveEntity(model);
}

Action OnItemTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	return Plugin_Handled;
}

void OnItemUse(int entity, int activator, int caller, UseType type, float value)
{
	if (!bIsValidEntity(entity))
	{
		return;
	}

	SDKUnhook(entity, SDKHook_OnTakeDamage, OnItemTakeDamage);
	SDKUnhook(entity, SDKHook_Use, OnItemUse);
}

#if defined MT_ABILITIES_MAIN
void vItemPluginCheck(ArrayList list)
#else
public void MT_OnPluginCheck(ArrayList list)
#endif
{
	list.PushString(MT_MENU_ITEM);
}

#if defined MT_ABILITIES_MAIN
void vItemAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#else
public void MT_OnAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#endif
{
	list.PushString(MT_ITEM_SECTION);
	list2.PushString(MT_ITEM_SECTION2);
	list3.PushString(MT_ITEM_SECTION3);
	list4.PushString(MT_ITEM_SECTION4);
}

#if defined MT_ABILITIES_MAIN
void vItemCombineAbilities(int tank, int type, const float random, const char[] combo)
#else
public void MT_OnCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
#endif
{
	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esItemCache[tank].g_iHumanAbility != 2)
	{
		return;
	}

	char sCombo[320], sSet[4][32];
	FormatEx(sCombo, sizeof sCombo, ",%s,", combo);
	FormatEx(sSet[0], sizeof sSet[], ",%s,", MT_ITEM_SECTION);
	FormatEx(sSet[1], sizeof sSet[], ",%s,", MT_ITEM_SECTION2);
	FormatEx(sSet[2], sizeof sSet[], ",%s,", MT_ITEM_SECTION3);
	FormatEx(sSet[3], sizeof sSet[], ",%s,", MT_ITEM_SECTION4);
	if (StrContains(sCombo, sSet[0], false) != -1 || StrContains(sCombo, sSet[1], false) != -1 || StrContains(sCombo, sSet[2], false) != -1 || StrContains(sCombo, sSet[3], false) != -1)
	{
		if (type == MT_COMBO_MAINRANGE && g_esItemCache[tank].g_iItemAbility == 1 && g_esItemCache[tank].g_iComboAbility == 1 && !g_esItemPlayer[tank].g_bActivated)
		{
			char sAbilities[320], sSubset[10][32];
			strcopy(sAbilities, sizeof sAbilities, combo);
			ExplodeString(sAbilities, ",", sSubset, sizeof sSubset, sizeof sSubset[]);

			float flDelay = 0.0;
			for (int iPos = 0; iPos < (sizeof sSubset); iPos++)
			{
				if (StrEqual(sSubset[iPos], MT_ITEM_SECTION, false) || StrEqual(sSubset[iPos], MT_ITEM_SECTION2, false) || StrEqual(sSubset[iPos], MT_ITEM_SECTION3, false) || StrEqual(sSubset[iPos], MT_ITEM_SECTION4, false))
				{
					if (random <= MT_GetCombinationSetting(tank, 1, iPos))
					{
						flDelay = MT_GetCombinationSetting(tank, 4, iPos);

						switch (flDelay)
						{
							case 0.0: g_esItemPlayer[tank].g_bActivated = true;
							default: CreateTimer(flDelay, tTimerItemCombo, GetClientUserId(tank), TIMER_FLAG_NO_MAPCHANGE);
						}
					}

					break;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vItemConfigsLoad(int mode)
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
				g_esItemAbility[iIndex].g_iAccessFlags = 0;
				g_esItemAbility[iIndex].g_iImmunityFlags = 0;
				g_esItemAbility[iIndex].g_flCloseAreasOnly = 0.0;
				g_esItemAbility[iIndex].g_iComboAbility = 0;
				g_esItemAbility[iIndex].g_iHumanAbility = 0;
				g_esItemAbility[iIndex].g_flOpenAreasOnly = 0.0;
				g_esItemAbility[iIndex].g_iRequiresHumans = 0;
				g_esItemAbility[iIndex].g_iItemAbility = 0;
				g_esItemAbility[iIndex].g_iItemMessage = 0;
				g_esItemAbility[iIndex].g_flItemChance = 33.3;
				g_esItemAbility[iIndex].g_sItemLoadout = "rifle,pistol,first_aid_kit,pain_pills";
				g_esItemAbility[iIndex].g_iItemMode = 0;
				g_esItemAbility[iIndex].g_sItemPinata[0] = '\0';
				g_esItemAbility[iIndex].g_iItemPinataBody = 1;
				g_esItemAbility[iIndex].g_flItemPinataChance = 33.3;
			}
		}
		case 3:
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (bIsValidClient(iPlayer))
				{
					g_esItemPlayer[iPlayer].g_iAccessFlags = 0;
					g_esItemPlayer[iPlayer].g_iImmunityFlags = 0;
					g_esItemPlayer[iPlayer].g_flCloseAreasOnly = 0.0;
					g_esItemPlayer[iPlayer].g_iComboAbility = 0;
					g_esItemPlayer[iPlayer].g_iHumanAbility = 0;
					g_esItemPlayer[iPlayer].g_flOpenAreasOnly = 0.0;
					g_esItemPlayer[iPlayer].g_iRequiresHumans = 0;
					g_esItemPlayer[iPlayer].g_iItemAbility = 0;
					g_esItemPlayer[iPlayer].g_iItemMessage = 0;
					g_esItemPlayer[iPlayer].g_flItemChance = 0.0;
					g_esItemPlayer[iPlayer].g_sItemLoadout[0] = '\0';
					g_esItemPlayer[iPlayer].g_iItemMode = 0;
					g_esItemPlayer[iPlayer].g_sItemPinata[0] = '\0';
					g_esItemPlayer[iPlayer].g_iItemPinataBody = 0;
					g_esItemPlayer[iPlayer].g_flItemPinataChance = 0.0;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vItemConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#else
public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#endif
{
	if (mode == 3 && bIsValidClient(admin))
	{
		g_esItemPlayer[admin].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_ITEM_SECTION, MT_ITEM_SECTION2, MT_ITEM_SECTION3, MT_ITEM_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esItemPlayer[admin].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esItemPlayer[admin].g_iComboAbility = iGetKeyValue(subsection, MT_ITEM_SECTION, MT_ITEM_SECTION2, MT_ITEM_SECTION3, MT_ITEM_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esItemPlayer[admin].g_iComboAbility, value, 0, 1);
		g_esItemPlayer[admin].g_iHumanAbility = iGetKeyValue(subsection, MT_ITEM_SECTION, MT_ITEM_SECTION2, MT_ITEM_SECTION3, MT_ITEM_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esItemPlayer[admin].g_iHumanAbility, value, 0, 2);
		g_esItemPlayer[admin].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_ITEM_SECTION, MT_ITEM_SECTION2, MT_ITEM_SECTION3, MT_ITEM_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esItemPlayer[admin].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esItemPlayer[admin].g_iRequiresHumans = iGetKeyValue(subsection, MT_ITEM_SECTION, MT_ITEM_SECTION2, MT_ITEM_SECTION3, MT_ITEM_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esItemPlayer[admin].g_iRequiresHumans, value, 0, 32);
		g_esItemPlayer[admin].g_iItemAbility = iGetKeyValue(subsection, MT_ITEM_SECTION, MT_ITEM_SECTION2, MT_ITEM_SECTION3, MT_ITEM_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esItemPlayer[admin].g_iItemAbility, value, 0, 1);
		g_esItemPlayer[admin].g_iItemMessage = iGetKeyValue(subsection, MT_ITEM_SECTION, MT_ITEM_SECTION2, MT_ITEM_SECTION3, MT_ITEM_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esItemPlayer[admin].g_iItemMessage, value, 0, 1);
		g_esItemPlayer[admin].g_flItemChance = flGetKeyValue(subsection, MT_ITEM_SECTION, MT_ITEM_SECTION2, MT_ITEM_SECTION3, MT_ITEM_SECTION4, key, "ItemChance", "Item Chance", "Item_Chance", "chance", g_esItemPlayer[admin].g_flItemChance, value, 0.0, 100.0);
		g_esItemPlayer[admin].g_iItemMode = iGetKeyValue(subsection, MT_ITEM_SECTION, MT_ITEM_SECTION2, MT_ITEM_SECTION3, MT_ITEM_SECTION4, key, "ItemMode", "Item Mode", "Item_Mode", "mode", g_esItemPlayer[admin].g_iItemMode, value, 0, 3);
		g_esItemPlayer[admin].g_iItemPinataBody = iGetKeyValue(subsection, MT_ITEM_SECTION, MT_ITEM_SECTION2, MT_ITEM_SECTION3, MT_ITEM_SECTION4, key, "ItemPinataBody", "Item Pinata Body", "Item_Pinata_Body", "pinatabody", g_esItemPlayer[admin].g_iItemPinataBody, value, 0, 1);
		g_esItemPlayer[admin].g_flItemPinataChance = flGetKeyValue(subsection, MT_ITEM_SECTION, MT_ITEM_SECTION2, MT_ITEM_SECTION3, MT_ITEM_SECTION4, key, "ItemPinataChance", "Item Pinata Chance", "Item_Pinata_Chance", "pinatachance", g_esItemPlayer[admin].g_flItemPinataChance, value, 0.0, 100.0);
		g_esItemPlayer[admin].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_ITEM_SECTION, MT_ITEM_SECTION2, MT_ITEM_SECTION3, MT_ITEM_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esItemPlayer[admin].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_ITEM_SECTION, MT_ITEM_SECTION2, MT_ITEM_SECTION3, MT_ITEM_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);

		vGetKeyValue(subsection, MT_ITEM_SECTION, MT_ITEM_SECTION2, MT_ITEM_SECTION3, MT_ITEM_SECTION4, key, "ItemLoadout", "Item Loadout", "Item_Loadout", "loadout", g_esItemPlayer[admin].g_sItemLoadout, sizeof esItemPlayer::g_sItemLoadout, value);
		vGetKeyValue(subsection, MT_ITEM_SECTION, MT_ITEM_SECTION2, MT_ITEM_SECTION3, MT_ITEM_SECTION4, key, "ItemPinata", "Item Pinata", "Item_Pinata", "pinata", g_esItemPlayer[admin].g_sItemPinata, sizeof esItemPlayer::g_sItemPinata, value);
	}

	if (mode < 3 && type > 0)
	{
		g_esItemAbility[type].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_ITEM_SECTION, MT_ITEM_SECTION2, MT_ITEM_SECTION3, MT_ITEM_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esItemAbility[type].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esItemAbility[type].g_iComboAbility = iGetKeyValue(subsection, MT_ITEM_SECTION, MT_ITEM_SECTION2, MT_ITEM_SECTION3, MT_ITEM_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esItemAbility[type].g_iComboAbility, value, 0, 1);
		g_esItemAbility[type].g_iHumanAbility = iGetKeyValue(subsection, MT_ITEM_SECTION, MT_ITEM_SECTION2, MT_ITEM_SECTION3, MT_ITEM_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esItemAbility[type].g_iHumanAbility, value, 0, 2);
		g_esItemAbility[type].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_ITEM_SECTION, MT_ITEM_SECTION2, MT_ITEM_SECTION3, MT_ITEM_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esItemAbility[type].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esItemAbility[type].g_iRequiresHumans = iGetKeyValue(subsection, MT_ITEM_SECTION, MT_ITEM_SECTION2, MT_ITEM_SECTION3, MT_ITEM_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esItemAbility[type].g_iRequiresHumans, value, 0, 32);
		g_esItemAbility[type].g_iItemAbility = iGetKeyValue(subsection, MT_ITEM_SECTION, MT_ITEM_SECTION2, MT_ITEM_SECTION3, MT_ITEM_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esItemAbility[type].g_iItemAbility, value, 0, 1);
		g_esItemAbility[type].g_iItemMessage = iGetKeyValue(subsection, MT_ITEM_SECTION, MT_ITEM_SECTION2, MT_ITEM_SECTION3, MT_ITEM_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esItemAbility[type].g_iItemMessage, value, 0, 1);
		g_esItemAbility[type].g_flItemChance = flGetKeyValue(subsection, MT_ITEM_SECTION, MT_ITEM_SECTION2, MT_ITEM_SECTION3, MT_ITEM_SECTION4, key, "ItemChance", "Item Chance", "Item_Chance", "chance", g_esItemAbility[type].g_flItemChance, value, 0.0, 100.0);
		g_esItemAbility[type].g_iItemMode = iGetKeyValue(subsection, MT_ITEM_SECTION, MT_ITEM_SECTION2, MT_ITEM_SECTION3, MT_ITEM_SECTION4, key, "ItemMode", "Item Mode", "Item_Mode", "mode", g_esItemAbility[type].g_iItemMode, value, 0, 3);
		g_esItemAbility[type].g_iItemPinataBody = iGetKeyValue(subsection, MT_ITEM_SECTION, MT_ITEM_SECTION2, MT_ITEM_SECTION3, MT_ITEM_SECTION4, key, "ItemPinataBody", "Item Pinata Body", "Item_Pinata_Body", "pinatabody", g_esItemAbility[type].g_iItemPinataBody, value, 0, 1);
		g_esItemAbility[type].g_flItemPinataChance = flGetKeyValue(subsection, MT_ITEM_SECTION, MT_ITEM_SECTION2, MT_ITEM_SECTION3, MT_ITEM_SECTION4, key, "ItemPinataChance", "Item Pinata Chance", "Item_Pinata_Chance", "pinatachance", g_esItemAbility[type].g_flItemPinataChance, value, 0.0, 100.0);
		g_esItemAbility[type].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_ITEM_SECTION, MT_ITEM_SECTION2, MT_ITEM_SECTION3, MT_ITEM_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esItemAbility[type].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_ITEM_SECTION, MT_ITEM_SECTION2, MT_ITEM_SECTION3, MT_ITEM_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);

		vGetKeyValue(subsection, MT_ITEM_SECTION, MT_ITEM_SECTION2, MT_ITEM_SECTION3, MT_ITEM_SECTION4, key, "ItemLoadout", "Item Loadout", "Item_Loadout", "loadout", g_esItemAbility[type].g_sItemLoadout, sizeof esItemAbility::g_sItemLoadout, value);
		vGetKeyValue(subsection, MT_ITEM_SECTION, MT_ITEM_SECTION2, MT_ITEM_SECTION3, MT_ITEM_SECTION4, key, "ItemPinata", "Item Pinata", "Item_Pinata", "pinata", g_esItemAbility[type].g_sItemPinata, sizeof esItemAbility::g_sItemPinata, value);
	}
}

#if defined MT_ABILITIES_MAIN
void vItemSettingsCached(int tank, bool apply, int type)
#else
public void MT_OnSettingsCached(int tank, bool apply, int type)
#endif
{
	bool bHuman = bIsTank(tank, MT_CHECK_FAKECLIENT);
	g_esItemCache[tank].g_flCloseAreasOnly = flGetSettingValue(apply, bHuman, g_esItemPlayer[tank].g_flCloseAreasOnly, g_esItemAbility[type].g_flCloseAreasOnly);
	g_esItemCache[tank].g_iComboAbility = iGetSettingValue(apply, bHuman, g_esItemPlayer[tank].g_iComboAbility, g_esItemAbility[type].g_iComboAbility);
	g_esItemCache[tank].g_flItemChance = flGetSettingValue(apply, bHuman, g_esItemPlayer[tank].g_flItemChance, g_esItemAbility[type].g_flItemChance);
	g_esItemCache[tank].g_flItemPinataChance = flGetSettingValue(apply, bHuman, g_esItemPlayer[tank].g_flItemPinataChance, g_esItemAbility[type].g_flItemPinataChance);
	g_esItemCache[tank].g_iHumanAbility = iGetSettingValue(apply, bHuman, g_esItemPlayer[tank].g_iHumanAbility, g_esItemAbility[type].g_iHumanAbility);
	g_esItemCache[tank].g_iItemAbility = iGetSettingValue(apply, bHuman, g_esItemPlayer[tank].g_iItemAbility, g_esItemAbility[type].g_iItemAbility);
	g_esItemCache[tank].g_iItemMessage = iGetSettingValue(apply, bHuman, g_esItemPlayer[tank].g_iItemMessage, g_esItemAbility[type].g_iItemMessage);
	g_esItemCache[tank].g_iItemMode = iGetSettingValue(apply, bHuman, g_esItemPlayer[tank].g_iItemMode, g_esItemAbility[type].g_iItemMode);
	g_esItemCache[tank].g_iItemPinataBody = iGetSettingValue(apply, bHuman, g_esItemPlayer[tank].g_iItemPinataBody, g_esItemAbility[type].g_iItemPinataBody);
	g_esItemCache[tank].g_flOpenAreasOnly = flGetSettingValue(apply, bHuman, g_esItemPlayer[tank].g_flOpenAreasOnly, g_esItemAbility[type].g_flOpenAreasOnly);
	g_esItemCache[tank].g_iRequiresHumans = iGetSettingValue(apply, bHuman, g_esItemPlayer[tank].g_iRequiresHumans, g_esItemAbility[type].g_iRequiresHumans);
	g_esItemPlayer[tank].g_iTankType = apply ? type : 0;

	vGetSettingValue(apply, bHuman, g_esItemCache[tank].g_sItemLoadout, sizeof esItemCache::g_sItemLoadout, g_esItemPlayer[tank].g_sItemLoadout, g_esItemAbility[type].g_sItemLoadout);
	vGetSettingValue(apply, bHuman, g_esItemCache[tank].g_sItemPinata, sizeof esItemCache::g_sItemPinata, g_esItemPlayer[tank].g_sItemPinata, g_esItemAbility[type].g_sItemPinata);
}

#if defined MT_ABILITIES_MAIN
void vItemCopyStats(int oldTank, int newTank)
#else
public void MT_OnCopyStats(int oldTank, int newTank)
#endif
{
	g_esItemPlayer[newTank].g_bActivated = g_esItemPlayer[oldTank].g_bActivated;
}

#if !defined MT_ABILITIES_MAIN
public void MT_OnPluginUpdate()
{
	MT_ReloadPlugin(null);
}
#endif

#if defined MT_ABILITIES_MAIN
void vItemEventFired(Event event, const char[] name)
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
			g_esItemPlayer[iTank].g_bActivated = g_esItemPlayer[iBot].g_bActivated;
		}
	}
	else if (StrEqual(name, "player_bot_replace"))
	{
		int iTankId = event.GetInt("player"), iTank = GetClientOfUserId(iTankId),
			iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId);
		if (bIsValidClient(iTank) && bIsTank(iBot))
		{
			g_esItemPlayer[iBot].g_bActivated = g_esItemPlayer[iTank].g_bActivated;
		}
	}
	else if (StrEqual(name, "player_death"))
	{
		int iTankId = event.GetInt("userid"), iTank = GetClientOfUserId(iTankId);
		if (MT_IsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME) && MT_IsCustomTankSupported(iTank) && g_esItemCache[iTank].g_iItemAbility == 1 && g_esItemPlayer[iTank].g_bActivated)
		{
			vItemAbility(iTank);
		}
	}
	else if (StrEqual(name, "mission_lost") || StrEqual(name, "round_start") || StrEqual(name, "round_end"))
	{
		vItemReset();
	}
}

#if defined MT_ABILITIES_MAIN
void vItemPlayerEventKilled(int victim, int attacker)
#else
public void MT_OnPlayerEventKilled(int victim, int attacker)
#endif
{
	if (bIsSurvivor(victim, MT_CHECK_INDEX|MT_CHECK_INGAME) && MT_IsTankSupported(attacker, MT_CHECK_INDEX|MT_CHECK_INGAME) && MT_IsCustomTankSupported(attacker) && g_esItemCache[attacker].g_sItemPinata[0] != '\0' && MT_GetRandomFloat(0.1, 100.0) <= g_esItemCache[attacker].g_flItemPinataChance)
	{
		float flPos[3];
		GetClientAbsOrigin(victim, flPos);
		flPos[2] += 50.0;

		char sItems[5][64];
		ReplaceString(g_esItemCache[attacker].g_sItemPinata, sizeof esItemCache::g_sItemPinata, " ", "");
		ExplodeString(g_esItemCache[attacker].g_sItemPinata, ",", sItems, sizeof sItems, sizeof sItems[]);
		for (int iItem = 0; iItem < (sizeof sItems); iItem++)
		{
			if (sItems[iItem][0] != '\0')
			{
				vSpawnItem(sItems[iItem], flPos);
			}
		}

		if (g_esItemCache[attacker].g_iItemPinataBody == 1)
		{
			g_iItemDeathModelOwner = GetClientUserId(victim);
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vItemAbilityActivated(int tank)
#else
public void MT_OnAbilityActivated(int tank)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esItemAbility[g_esItemPlayer[tank].g_iTankType].g_iAccessFlags, g_esItemPlayer[tank].g_iAccessFlags)) || g_esItemCache[tank].g_iHumanAbility == 0))
	{
		return;
	}

	if (MT_IsTankSupported(tank) && (!bIsTank(tank, MT_CHECK_FAKECLIENT) || g_esItemCache[tank].g_iHumanAbility != 1) && MT_IsCustomTankSupported(tank) && g_esItemCache[tank].g_iItemAbility == 1 && g_esItemCache[tank].g_iComboAbility == 0 && MT_GetRandomFloat(0.1, 100.0) <= g_esItemCache[tank].g_flItemChance && !g_esItemPlayer[tank].g_bActivated)
	{
		g_esItemPlayer[tank].g_bActivated = true;
	}
}

#if defined MT_ABILITIES_MAIN
void vItemButtonPressed(int tank, int button)
#else
public void MT_OnButtonPressed(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && MT_IsCustomTankSupported(tank))
	{
		if (bIsAreaNarrow(tank, g_esItemCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esItemCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esItemPlayer[tank].g_iTankType) || (g_esItemCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esItemCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esItemAbility[g_esItemPlayer[tank].g_iTankType].g_iAccessFlags, g_esItemPlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		if ((button & MT_SPECIAL_KEY2) && g_esItemCache[tank].g_iItemAbility == 1 && g_esItemCache[tank].g_iHumanAbility == 1)
		{
			switch (g_esItemPlayer[tank].g_bActivated)
			{
				case true: MT_PrintToChat(tank, "%s %t", MT_TAG3, "ItemHuman2");
				case false:
				{
					g_esItemPlayer[tank].g_bActivated = true;

					MT_PrintToChat(tank, "%s %t", MT_TAG3, "ItemHuman");
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vItemChangeType(int tank, int oldType)
#else
public void MT_OnChangeType(int tank, int oldType, int newType, bool revert)
#endif
{
	if (oldType <= 0 || (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esItemAbility[g_esItemPlayer[tank].g_iTankType].g_iAccessFlags, g_esItemPlayer[tank].g_iAccessFlags)) || g_esItemCache[tank].g_iHumanAbility == 0)))
	{
		return;
	}

	if (MT_IsTankSupported(tank) && MT_IsCustomTankSupported(tank) && g_esItemCache[tank].g_iItemAbility == 1)
	{
		vItemAbility(tank);
	}
}

void vItemAbility(int tank)
{
	g_esItemPlayer[tank].g_bActivated = false;

	if (bIsAreaNarrow(tank, g_esItemCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esItemCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esItemPlayer[tank].g_iTankType) || (g_esItemCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esItemCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esItemAbility[g_esItemPlayer[tank].g_iTankType].g_iAccessFlags, g_esItemPlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	char sItems[5][64];
	ReplaceString(g_esItemCache[tank].g_sItemLoadout, sizeof esItemCache::g_sItemLoadout, " ", "");
	ExplodeString(g_esItemCache[tank].g_sItemLoadout, ",", sItems, sizeof sItems, sizeof sItems[]);

	switch (g_esItemCache[tank].g_iItemMode)
	{
		case 0, 1:
		{
			for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
			{
				if (bIsSurvivor(iSurvivor, MT_CHECK_INGAME|MT_CHECK_ALIVE) && !MT_IsAdminImmune(iSurvivor, tank) && !bIsAdminImmune(iSurvivor, g_esItemPlayer[tank].g_iTankType, g_esItemAbility[g_esItemPlayer[tank].g_iTankType].g_iImmunityFlags, g_esItemPlayer[iSurvivor].g_iImmunityFlags))
				{
					switch (g_esItemCache[tank].g_iItemMode)
					{
						case 0: vCheatCommand(iSurvivor, "give", sItems[MT_GetRandomInt(1, (sizeof sItems)) - 1]);
						case 1: vItemLoadout(tank, iSurvivor, sItems, sizeof sItems);
					}
				}
			}
		}
		case 2: vCheatCommand(tank, "give", sItems[MT_GetRandomInt(1, (sizeof sItems)) - 1]);
		case 3: vItemLoadout(tank, tank, sItems, sizeof sItems);
	}

	if (g_esItemCache[tank].g_iItemMessage == 1)
	{
		char sTankName[33];
		MT_GetTankName(tank, sTankName);
		MT_PrintToChatAll("%s %t", MT_TAG2, "Item", sTankName);
		MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Item", LANG_SERVER, sTankName);
	}
}

void vItemLoadout(int tank, int survivor, const char[][] list, int size)
{
	for (int iItem = 0; iItem < size; iItem++)
	{
		if (StrContains(g_esItemCache[tank].g_sItemLoadout, list[iItem]) != -1 && list[iItem][0] != '\0')
		{
			vCheatCommand(survivor, "give", list[iItem]);
		}
	}
}

void vItemReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
		{
			g_esItemPlayer[iPlayer].g_bActivated = false;
		}
	}
}

void vSpawnItem(const char[] name, float pos[3])
{
	char sClassname[32];
	int iItem = -1, iType = 0;
	if (StrEqual(name, "gascan") || StrEqual(name, "propanetank") || StrEqual(name, "oxygentank") || StrEqual(name, "fireworkcrate"))
	{
		iType = 1;
	}
	else if (StrEqual(name, "grenade_launcher") || strncmp(name, "pistol", 6) == 0 || strncmp(name, "rifle", 6) != -1
		|| strncmp(name, "smg", 3) == 0 || strncmp(name, "shotgun", 7) != -1 || strncmp(name, "sniper", 6) == 0)
	{
		iType = 2;
	}
	else if (StrEqual(name, "molotov") || StrEqual(name, "pipe_bomb") || StrEqual(name, "vomitjar") || StrEqual(name, "first_aid_kit")
		|| StrEqual(name, "defibrillator") || strncmp(name, "upgrade", 7) != -1 || StrEqual(name, "pain_pills") || StrEqual(name, "adrenaline"))
	{
		iType = 3;
	}
	else
	{
		iType = 4;
	}

	switch (iType)
	{
		case 1:
		{
			FormatEx(sClassname, sizeof sClassname, "weapon_%s", name);

			switch (StrEqual(sClassname[7], "gascan"))
			{
				case true: iItem = CreateEntityByName(sClassname);
				case false:
				{
					iItem = CreateEntityByName("prop_physics");
					if (bIsValidEntity(iItem))
					{
						if (StrEqual(name, "fireworkcrate"))
						{
							SetEntityModel(iItem, MODEL_FIREWORKCRATE);
						}
						else if (StrEqual(name, "oxygentank"))
						{
							SetEntityModel(iItem, MODEL_OXYGENTANK);
						}
						else if (StrEqual(name, "propanetank"))
						{
							SetEntityModel(iItem, MODEL_PROPANETANK);
						}
					}
				}
			}

			if (bIsValidEntity(iItem))
			{
				SDKHook(iItem, SDKHook_OnTakeDamage, OnItemTakeDamage);
				SDKHook(iItem, SDKHook_Use, OnItemUse);
				CreateTimer(3.0, tTimerRemoveItemHooks, EntIndexToEntRef(iItem), TIMER_FLAG_NO_MAPCHANGE);
			}
		}
		case 2, 3:
		{
			FormatEx(sClassname, sizeof sClassname, "weapon_%s", name);
			iItem = CreateEntityByName(sClassname);
		}
		case 4:
		{
			iItem = CreateEntityByName("weapon_melee");
			if (bIsValidEntity(iItem))
			{
				DispatchKeyValue(iItem, "melee_script_name", name);
			}
		}
	}

	if (bIsValidEntity(iItem))
	{
		TeleportEntity(iItem, pos);
		DispatchSpawn(iItem);
		ActivateEntity(iItem);

		if (iType == 2)
		{
			if (strncmp(name, "rifle", 6) == 0)
			{
				SetEntProp(iItem, Prop_Send, "m_iExtraPrimaryAmmo", 300);
			}
			else if (strncmp(name, "smg", 3) == 0)
			{
				SetEntProp(iItem, Prop_Send, "m_iExtraPrimaryAmmo", 600);
			}
			else if (StrEqual(name, "autoshotgun") || StrEqual(name, "shotgun_spas"))
			{
				SetEntProp(iItem, Prop_Send, "m_iExtraPrimaryAmmo", 100);
			}
			else if (StrEqual(name, "pumpshotgun") || StrEqual(name, "shotgun_chrome"))
			{
				SetEntProp(iItem, Prop_Send, "m_iExtraPrimaryAmmo", 50);
			}
			else if (StrEqual(name, "hunting_rifle") || strncmp(name, "sniper", 6) == 0)
			{
				SetEntProp(iItem, Prop_Send, "m_iExtraPrimaryAmmo", 150);
			}
		}
	}
}

Action tTimerItemCombo(Handle timer, int userid)
{
	int iTank = GetClientOfUserId(userid);
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esItemAbility[g_esItemPlayer[iTank].g_iTankType].g_iAccessFlags, g_esItemPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esItemPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esItemCache[iTank].g_iItemAbility == 0 || g_esItemPlayer[iTank].g_bActivated)
	{
		return Plugin_Stop;
	}

	g_esItemPlayer[iTank].g_bActivated = true;

	return Plugin_Continue;
}

Action tTimerRemoveItemHooks(Handle timer, int ref)
{
	int iItem = EntRefToEntIndex(ref);
	if (!bIsValidEntity(iItem))
	{
		return Plugin_Stop;
	}

	SDKUnhook(iItem, SDKHook_OnTakeDamage, OnItemTakeDamage);
	SDKUnhook(iItem, SDKHook_Use, OnItemUse);

	return Plugin_Continue;
}