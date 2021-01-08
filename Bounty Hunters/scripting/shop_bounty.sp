#pragma semicolon 1
#pragma newdecls required

#include <multicolors>
#include <csgo_colors>
#include <shop>

#define GAME_UNDEFINED 0
#define GAME_CSS_34 1
#define GAME_CSS 2
#define GAME_CSGO 3

bool bEnableColors,
	ClientHasBounty[MAXPLAYERS+1] ={false, ...},
	bBounty;

Handle	g_BountyStart = INVALID_HANDLE,
	g_BountyKills = INVALID_HANDLE,
	g_BountyHeadshot = INVALID_HANDLE,
	g_BountyKill = INVALID_HANDLE,
	g_BountyRound = INVALID_HANDLE,
	g_BountyDisplay = INVALID_HANDLE,
	g_BountyBomb = INVALID_HANDLE,
	g_BountyHostie = INVALID_HANDLE;

int ClientKills[MAXPLAYERS+1],
	ClientBounty[MAXPLAYERS+1],
	iClients;

char Engine_Version;

int GetCSGame()
{
	if (GetFeatureStatus(FeatureType_Native, "GetEngineVersion") == FeatureStatus_Available) 
	{ 
		switch (GetEngineVersion()) 
		{ 
			case Engine_SourceSDK2006: return GAME_CSS_34; 
			case Engine_CSS: return GAME_CSS; 
			case Engine_CSGO: return GAME_CSGO; 
		}
	}
	return GAME_UNDEFINED;
}

public Plugin myinfo = 
{
	name = "[Shop Core] Bounty und Colors",
	author = "Dr!fter (rewritten Nek.'a 2x2 | ggwp.site )",
	description = "Охотники за головами",
	version = "1.2.5",
	url = "https://ggwp.site/"
}
public void OnPluginStart()
{
	Engine_Version = GetCSGame();
	if (Engine_Version == GAME_UNDEFINED) SetFailState("Game is not supported!");
	if(Engine_Version == GAME_CSS_34) LoadTranslations("shop_bounty_cssv34");
	if(Engine_Version == GAME_CSS) LoadTranslations("shop_bounty_css");
	if(Engine_Version == GAME_CSGO) LoadTranslations("shop_bounty_csgo");
	
	LoadTranslations("common.phrases");
	
	ConVar cvar;
	cvar = CreateConVar("sm_bounty_enablecolor", "1", "Turn on / off painting of players", _, true, _, true, 1.0);
	cvar.AddChangeHook(CVarChanged_EnableColors);
	bEnableColors = cvar.BoolValue;
	cvar = CreateConVar("sm_bounty", "1", "Enable disable plugin", _, true, _, true, 1.0);
	cvar.AddChangeHook(CVarChanged_EnableColors);
	bBounty = cvar.BoolValue;
	g_BountyKills = CreateConVar("sm_bounty_kills", "5", "How many kills are needed to start the hunt.");
	g_BountyStart = CreateConVar("sm_bounty_start", "50", "The initial amount of credits for hunting, after comprehending this variable sm_bounty_kills");
	g_BountyHeadshot = CreateConVar("sm_bounty_headshot", "20", "Headshot bonus amount.");
	g_BountyKill = CreateConVar("sm_bounty_bonus", "25", "Player credits bonus for killing a victim");
	g_BountyRound = CreateConVar("sm_bounty_round", "25", "Bonus credits for every round that he survives.");
	g_BountyHostie = CreateConVar("sm_bounty_hostie", "2", "How much the reward should be increased for each new sacrifice.");
	g_BountyBomb = CreateConVar("sm_bounty_bomb", "25", "How many credits are awarded for planting a bomb if it explodes. (to the amount per head)");
	g_BountyDisplay = CreateConVar("sm_bounty_display", "1", "1 = Write to chat 2 = centered 0 = disable message");
	
	AutoExecConfig(true, "shop_bounty", "shop");
	
	HookEvent("player_death", EventPlayerDeath);
	HookEvent("round_end", EventRoundEnd);
	HookEvent("hostage_rescued", EventHostage);
	HookEvent("bomb_exploded", EventBomb);
	//HookEvent("round_start", round_start);

	RegConsoleCmd("sm_sb", CmdCheckList);
	RegAdminCmd("sm_setbounty", CmdSetBounty, ADMFLAG_CONVARS, "Command for setting the bet per player's head.");
}

public void OnMapStart()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		ClientKills[i] = 0;
		ClientBounty[i] = 0;
		ClientHasBounty[i] = false;
	}
}

public void CVarChanged_EnableColors(ConVar CVar, const char[] oldValue, const char[] newValue)
{
	bBounty = CVar.BoolValue;
	bEnableColors = CVar.BoolValue;
}

public Action EventHostage(Handle event, const char[] name, bool dontBroadcast)
{
	iClients = GetClientOfUserId(GetEventInt(event, "userid"));
	if(iClients != 0 && IsClientInGame(iClients)&& ClientHasBounty[iClients] && IsPlayerAlive(iClients))
		ClientBounty[iClients] += GetConVarInt(g_BountyHostie);
}

public Action EventBomb(Handle event, const char[] name, bool dontBroadcast)
{
	iClients = GetClientOfUserId(GetEventInt(event, "userid"));
	if(iClients != 0 && IsClientInGame(iClients) && ClientHasBounty[iClients] && IsPlayerAlive(iClients))
		ClientBounty[iClients] += GetConVarInt(g_BountyBomb);
}

public Action EventPlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
	if(bBounty)
	{		
		iClients = GetClientOfUserId(GetEventInt(event, "userid"));
		int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
		bool Headshot = GetEventBool(event, "headshot");
		char AttackerName[100], ClientName[100];
		GetClientName(attacker, AttackerName, sizeof(AttackerName));
		GetClientName(iClients, ClientName, sizeof(ClientName));
		if(IsValidKill(iClients, attacker))
		{
			ClientKills[attacker]++;
			if(ClientHasBounty[attacker])
				ClientBounty[attacker] += GetConVarInt(g_BountyKill);
			if(ClientHasBounty[attacker] && Headshot)
				ClientBounty[attacker] += GetConVarInt(g_BountyHeadshot);
			if(ClientKills[attacker] == GetConVarInt(g_BountyKills))
			{
				ClientHasBounty[attacker] = true;
				ClientBounty[attacker] = GetConVarInt(g_BountyStart);
				if(GetConVarInt(g_BountyDisplay) == 1)
					CPrintToChatAll("%t", "reward_for_a_head_shot_say_all", AttackerName);
				else if(GetConVarInt(g_BountyDisplay) == 2)
					PrintCenterTextAll("%t", "reward_for_a_head_shot_say_center_all", AttackerName);		//************************************************
			}
			if(ClientHasBounty[iClients])
			{
				if(GetConVarInt(g_BountyDisplay) == 1)
					CPrintToChatAll("%t", "reward_for_murder_say_all", AttackerName, ClientName, ClientBounty[iClients]);
				else if(GetConVarInt(g_BountyDisplay) == 2)
					PrintCenterTextAll("%t", "reward_for_murder_say_canter_all", AttackerName, ClientName, ClientBounty[iClients]);		//******************************************
				if(!IsFakeClient(attacker))
				Shop_GiveClientCredits(attacker, ClientBounty[iClients]);
			}
		}
		ClientKills[iClients] = 0;
		ClientHasBounty[iClients] = false;
		ClientBounty[iClients] = 0;
	}
}

public Action EventRoundEnd(Handle event, const char[] name, bool dontBroadcast)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && ClientHasBounty[i] && IsPlayerAlive(i))
		{
			ClientBounty[i] += GetConVarInt(g_BountyRound);
			if(GetConVarInt(g_BountyDisplay) == 1) CPrintToChat(i, "%t", "bounty_on_your_head", ClientBounty[i]);
			else if(GetConVarInt(g_BountyDisplay) == 2) PrintCenterText(i, "%t", "bounty_on_your_head_center", ClientBounty[i]);
		}
		if(IsClientInGame(i) && !IsPlayerAlive(i))
		{
			ClientKills[i] = 0;
			ClientHasBounty[i] = false;
			ClientBounty[i] = 0;
		}
	}
}

public Action CmdCheckList(int client, int args)
{	
	DisplayBountyPanel(client);
	return Plugin_Handled;
}

public void OniClientsisconnect(int client)
{
	ClientKills[iClients] = 0;
	ClientBounty[iClients] = 0;
	ClientHasBounty[iClients] = false;
}

void DisplayBountyPanel(int client)
{
	bool bounty;
	Handle BountyPanel = CreatePanel();
	SetPanelTitle(BountyPanel, "Ставка за голову");
	for(int i = 1; i <= MaxClients; i++)
	{
		if(ClientHasBounty[i])
		{
		bounty = true;
		char name[100], text[120];
		GetClientName(i, name, sizeof(name));
		Format(text, sizeof(text), "%s  |  %d credits", name, ClientBounty[i]);
		DrawPanelText(BountyPanel, text);
		}
	}
	if(bounty)
	{
		DrawPanelText(BountyPanel, "Press 0 to exit");
		SendPanelToClient(BountyPanel, client, MenuHandle, 10);
	}
	else CPrintToChat(client, "%t", "no_awards");
}

public int MenuHandle(Handle menu, MenuAction action, int parm1, int parm2)
{
	if (action == MenuAction_End)
	{
		//	Nothing... just an empty function.
	}
}
stock bool IsValidKill(int client, int attacker)
{
	if(iClients != 0 && attacker != 0 && iClients != attacker && iClients <= MaxClients && attacker <= MaxClients && GetClientTeam(iClients) != GetClientTeam(attacker))
		return true;
	return false;
}
public Action CmdSetBounty(int client, int args)
{
	char targetName[128], stringint[10];
	if(args < 2)
	{
		ReplyToCommand(iClients, "[SM] sm_setbounty <target> <ammount>");
		return Plugin_Handled;
	}
	GetCmdArg(1, targetName, sizeof(targetName));
	int targetClient = FindTarget(iClients, targetName, false, true);
	if(IsClientInGame(client) && targetClient == -1) 
	{
		CPrintToChat(iClients, "\x04Target not found");
		return Plugin_Handled;
	}
	
	GetClientName(targetClient, targetName, sizeof(targetName));
	GetCmdArg(2, stringint, sizeof(stringint));
	int ammount = StringToInt(stringint);
	ClientBounty[targetClient] = ammount;
	ClientHasBounty[targetClient] = true;
	if(GetConVarInt(g_BountyDisplay) == 1)
		CPrintToChatAll("%t", "reward_has_been_set", targetName, ammount);
	else if(GetConVarInt(g_BountyDisplay) == 2)
		PrintCenterTextAll("%t", "reward_has_been_set_center", targetName, ammount);
		
	if(bEnableColors)
	{
		static int clr[4];
		clr[3] = 255;
		clr[0] = GetRandomInt(0, 255);
		clr[1] = GetRandomInt(0, 255);
		clr[2] = GetRandomInt(0, 255);
		SetEntityRenderMode(targetClient, RENDER_TRANSCOLOR);
		SetEntityRenderColor(targetClient, clr[0], clr[1], clr[2]);
	}
	return Plugin_Handled;
}
/*
public void round_start(Event event, const char[] name, bool dontBroadcast)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(ClientHasBounty[i])
		{
			static int clr[4];
			clr[3] = 255;
			clr[0] = GetRandomInt(0, 255);
			clr[1] = GetRandomInt(0, 255);
			clr[2] = GetRandomInt(0, 255);
			SetEntityRenderMode(ClientBounty[i], RENDER_TRANSCOLOR);
			SetEntityRenderColor(ClientBounty[i], clr[0], clr[1], clr[2]);
		}
	}
}*/