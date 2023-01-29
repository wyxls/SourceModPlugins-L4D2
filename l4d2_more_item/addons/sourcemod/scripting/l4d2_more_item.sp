#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#define CVAR_FLAGS		FCVAR_NOTIFY
#define PLUGIN_VERSION	"1.1"

//玩家连接时播放的声音.
#define IsConnected		"buttons/button11.wav"
//玩家离开时播放的声音.
#define IsDisconnect	"buttons/button4.wav"

#define	SurvivorsSound		(1 << 0)
#define SurvivorsMultiple	(1 << 1)
#define SurvivorsPrompt		(1 << 2)

bool g_bPlayerPrompt, g_bMoreItem, g_bMedicalCheck;

int g_iPlayerNumber;

int    g_iMoreItem;
int    g_iMoreGuns;
int    g_iMoreMelees;
int    g_iMoreThrows;
int    g_iMoreMedics;
ConVar g_hMoreItem;
ConVar g_hMoreGuns;
ConVar g_hMoreMelees;
ConVar g_hMorethrows;
ConVar g_hMoreMedics;


public Plugin myinfo = 
{
	name 			= "l4d2_more_item",
	author 			= "Zakikun",
	description 	= "根据玩家人数设置所有物品倍数.",
	version 		= PLUGIN_VERSION,
	url 			= "https://github.com/wyxls/SourceModPlugins-L4D2"
}

public void OnPluginStart()
{
	g_hMoreItem = CreateConVar("l4d2_more_item_function", "7", "把需要启用的功能数字相加. 0=禁用, 1=声音, 2=倍数, 4=提示.", CVAR_FLAGS);
	g_hMoreGuns = CreateConVar("l4d2_more_item_guns", "1", "是否启用枪械武器倍数.", CVAR_FLAGS);
	g_hMoreMelees = CreateConVar("l4d2_more_item_melees", "1", "是否启用近战武器倍数. 0=禁用, 1=声音, 2=倍数, 4=提示.", CVAR_FLAGS);
	g_hMorethrows = CreateConVar("l4d2_more_item_throws", "0", "是否启用投掷物倍数. 0=禁用, 1=声音, 2=倍数, 4=提示.", CVAR_FLAGS);
	g_hMoreMedics = CreateConVar("l4d2_more_item_medics", "1", "是否启用医疗物品倍数. 0=禁用, 1=声音, 2=倍数, 4=提示.", CVAR_FLAGS);

	g_hMoreItem.AddChangeHook(ConVarChanged);
	AutoExecConfig(true, "l4d2_more_item");//  生成指定文件名的CFG.
	HookEvent("round_end", Event_RoundEnd);//  回合结束事件.
	HookEvent("round_start", Event_RoundStart);//  回合开始事件.
}

//地图开始
public void OnMapStart()
{	
	GetCvarsMedical();
	g_iPlayerNumber = 0;
	g_bMoreItem = false;
	g_bMedicalCheck = false;
}

public void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvarsMedical();
}

void GetCvarsMedical()
{
	g_iMoreItem = g_hMoreItem.IntValue;
	g_iMoreGuns = g_hMoreGuns.IntValue;
	g_iMoreMelees = g_hMoreMelees.IntValue;
	g_iMoreThrows = g_hMorethrows.IntValue;
	g_iMoreMedics = g_hMoreMedics.IntValue;
}

//玩家连接成功.
public void OnClientPostAdminCheck(int client)
{
	if(IsFakeClient(client))
		return;
	
	if(!g_bMedicalCheck)
	{
		g_bMedicalCheck = true;
		DataPack hPack;
		CreateDataTimer(1.0, IsCreateMoreItemTimer, hPack, TIMER_FLAG_NO_MAPCHANGE);
		hPack.WriteCell(false);
	}
}

//玩家连接
public void OnClientConnected(int client)
{   
	if(IsFakeClient(client))
		return;

	g_iPlayerNumber += 1;
	IsPlayerMultiple(true, true, true, client, g_iPlayerNumber, GetSurvivorLimit());
}

//玩家退出
public void OnClientDisconnect(int client)
{   
	if(IsFakeClient(client))
		return;
	
	g_iPlayerNumber -=1 ;
	IsPlayerMultiple(true, false, true, client, g_iPlayerNumber, GetSurvivorLimit());
}

//回合结束.
public void Event_RoundEnd(Event event, const char [] name, bool dontBroadcast)
{
	g_bMoreItem = true;
}

//回合开始.
public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if(g_bMoreItem)
	{
		g_bMoreItem = false;
		DataPack hPack;
		CreateDataTimer(1.0, IsCreateMoreItemTimer, hPack, TIMER_FLAG_NO_MAPCHANGE);
		hPack.WriteCell(true);
	}
}

//回合开始或玩家连接成功.
public Action IsCreateMoreItemTimer(Handle Timer, DataPack hPack)
{
	hPack.Reset();
	bool g_bMoreCheck = hPack.ReadCell();
	IsPlayerMultiple(false, false, g_bMoreCheck, 0, GetAllPlayerCount(), GetSurvivorLimit());
	return Plugin_Continue;
}

void IsPlayerMultiple(bool g_bPrompt, bool g_bContent, bool g_bMoreCheck, int client, int g_iClientNumber, int g_iSurvivorLimit)
{
	switch (g_iClientNumber)
	{
		case 1,2,3,4:
			IsSetUpdateEntCount(client, 1, g_bPrompt, g_bContent, g_bMoreCheck, g_iClientNumber, g_iSurvivorLimit);
		case 5,6,7,8:
			IsSetUpdateEntCount(client, 2, g_bPrompt, g_bContent, g_bMoreCheck, g_iClientNumber, g_iSurvivorLimit);
		case 9,10,11,12:
			IsSetUpdateEntCount(client, 3, g_bPrompt, g_bContent, g_bMoreCheck, g_iClientNumber, g_iSurvivorLimit);
		case 13,14,15,16:
			IsSetUpdateEntCount(client, 4, g_bPrompt, g_bContent, g_bMoreCheck, g_iClientNumber, g_iSurvivorLimit);
		case 17,18,19,20:
			IsSetUpdateEntCount(client, 5, g_bPrompt, g_bContent, g_bMoreCheck, g_iClientNumber, g_iSurvivorLimit);
		case 21,22,23,24:
			IsSetUpdateEntCount(client, 6, g_bPrompt, g_bContent, g_bMoreCheck, g_iClientNumber, g_iSurvivorLimit);
	}
}

void IsSetUpdateEntCount(int client, int g_Multiple, bool g_bPrompt, bool g_bContent, bool g_bMoreCheck, int g_iClientNumber, int g_iSurvivorLimit)
{
	if(g_iMoreItem == 0)
		return;

	char g_sMedical[32];
	IntToString(g_Multiple, g_sMedical, sizeof(g_sMedical));
	g_bPlayerPrompt = false;

	if(g_iMoreItem & SurvivorsSound)
	{
		if(g_bPrompt)
			IsPlaySound(g_bContent);//播放声音.
	}
	if(g_iMoreItem & SurvivorsMultiple)
	{
		g_bPlayerPrompt = true;

		// 枪械
		if(g_iMoreGuns)
		{
			SetUpdateEntCount("weapon_autoshotgun_spawn", g_sMedical);
			SetUpdateEntCount("weapon_pumpshotgun_spawn", g_sMedical);
			SetUpdateEntCount("weapon_hunting_rifle_spawn", g_sMedical);
			SetUpdateEntCount("weapon_pistol_spawn", g_sMedical);
			SetUpdateEntCount("weapon_pistol_magnum_spawn", g_sMedical);
			SetUpdateEntCount("weapon_rifle_spawn", g_sMedical);
			SetUpdateEntCount("weapon_rifle_ak47_spawn", g_sMedical);
			SetUpdateEntCount("weapon_rifle_desert_spawn", g_sMedical);
			SetUpdateEntCount("weapon_rifle_sg552_spawn", g_sMedical);
			SetUpdateEntCount("weapon_shotgun_chrome_spawn", g_sMedical);
			SetUpdateEntCount("weapon_shotgun_spas_spawn", g_sMedical);
			SetUpdateEntCount("weapon_smg_spawn", g_sMedical);
			SetUpdateEntCount("weapon_smg_mp5_spawn", g_sMedical);
			SetUpdateEntCount("weapon_smg_silenced_spawn", g_sMedical);
			SetUpdateEntCount("weapon_sniper_awp_spawn", g_sMedical);
			SetUpdateEntCount("weapon_sniper_military_spawn", g_sMedical);
			SetUpdateEntCount("weapon_sniper_scout_spawn", g_sMedical);
			SetUpdateEntCount("weapon_grenade_launcher_spawn", g_sMedical);
			SetUpdateEntCount("weapon_spawn", g_sMedical);						// 随机二代武器
		}

		// 近战武器
		if(g_iMoreMelees)
		{
			SetUpdateEntCount("weapon_chainsaw_spawn", g_sMedical);				//燃油链锯
			SetUpdateEntCount("weapon_melee_spawn", g_sMedical);
		}

		// 投掷物
		if(g_iMoreThrows)
		{
			SetUpdateEntCount("weapon_molotov_spawn", g_sMedical);					//燃烧瓶
			SetUpdateEntCount("weapon_vomitjar_spawn", g_sMedical);					//胆汁罐
			SetUpdateEntCount("weapon_pipe_bomb_spawn", g_sMedical);				//土质炸弹
		}

		// 医疗物品
		if(g_iMoreMedics)
		{
			SetUpdateEntCount("weapon_adrenaline_spawn", g_sMedical);				//肾上腺素
			SetUpdateEntCount("weapon_defibrillator_spawn", g_sMedical);			//电击器
			SetUpdateEntCount("weapon_first_aid_kit_spawn", g_sMedical);			//医疗包
			SetUpdateEntCount("weapon_pain_pills_spawn", g_sMedical);				//止痛药
		}

	}

	if(g_iMoreItem & SurvivorsPrompt && g_bMoreCheck)
	{
		if(g_bPrompt)
			if(!g_bPlayerPrompt)
				PrintToChatAll("\x04[MoreItem]\x03%N\x05%s\x04(\x03%i\x05/\x03%d\x04)\x03...\x04%s", client, g_bContent ? "正在连接" : "离开游戏", g_iPlayerNumber, g_iSurvivorLimit, g_bContent);
			else
				PrintToChatAll("\x04[MoreItem]\x03%N\x05%s\x04(\x03%i\x05/\x03%d\x04)\x03,\x05更改为\x03%s\x05倍物资.", client, g_bContent ? "正在连接" : "离开游戏", g_iPlayerNumber, g_iSurvivorLimit, g_sMedical);
		else
			PrintToChatAll("\x04[MoreItem]\x05当前人数为\x03:\x04(\x03%i\x05/\x03%d\x04)\x03,\x05更改为\x03%s\x05倍物资.", g_iClientNumber, g_iSurvivorLimit, g_sMedical);
	}
}

//播放声音.
void IsPlaySound(bool g_bContent)
{
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && !IsFakeClient(i))
			EmitSoundToClient(i, g_bContent ? IsConnected : IsDisconnect);
}

//设置物品倍数.
void SetUpdateEntCount(const char [] entname, const char [] count)
{
	int edict_index = FindEntityByClassname(-1, entname);
	
	while(edict_index != -1)
	{
		DispatchKeyValue(edict_index, "count", count);
		edict_index = FindEntityByClassname(edict_index, entname);
	}
}

//获取服务器最大人数.
int GetSurvivorLimit()
{
	static int g_iMaxcl = 0;
	static Handle invalid = null, downtownrun = null, toolzrun = null;
	downtownrun = FindConVar("l4d_maxplayers");
	toolzrun	= FindConVar("sv_maxplayers");
	if (downtownrun != (invalid))
	{
		int downtown = (GetConVarInt(FindConVar("l4d_maxplayers")));
		if (downtown >= 1)
			g_iMaxcl = (GetConVarInt(FindConVar("l4d_maxplayers")));
	}
	if (toolzrun != (invalid))
	{
		int toolz = (GetConVarInt(FindConVar("sv_maxplayers")));
		if (toolz >= 1)
			g_iMaxcl = (GetConVarInt(FindConVar("sv_maxplayers")));
	}
	if (downtownrun == (invalid) && toolzrun == (invalid))
		g_iMaxcl = (MaxClients);

	return g_iMaxcl;
}

//获取玩家数量.
int GetAllPlayerCount()
{
	int count = 0;
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientConnected(i) && !IsFakeClient(i))
				count++;
	
	return count;
}