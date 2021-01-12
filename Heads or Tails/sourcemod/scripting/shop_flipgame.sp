#include <sourcemod>
#include <csgo_colors>
#include <shop>
#include <clientprefs>

#pragma semicolon 1

char pl_tag[] =	"{DEFAULT}[{LIGHTGREEN}Flip Game{DEFAULT}]";

char cFlipCoin[][] = {"Heads", "Tails"};
int iClientCoin[MAXPLAYERS+1][2]; //Coin side | 0 - before the game | 1 - fix in the game
int iPreCredits[MAXPLAYERS+1][3]; //Rate | 0 - wants to put | 1 - already put | 2 - sent an offer
bool IsClientInPlay[MAXPLAYERS+1]; //If the player is in the game
int iFlipTime[MAXPLAYERS+1]; //Game timer

float UpTimer[MAXPLAYERS+1];
int UTimer[MAXPLAYERS+1];
int iWin[MAXPLAYERS+1];
char USussces[MAXPLAYERS+1][4][64];
char sColor[MAXPLAYERS+1][4][32];

int iStats[MAXPLAYERS+1][5];
Handle:g_hCookie;
Handle:hWriteTimer[MAXPLAYERS+1] = INVALID_HANDLE;
bool bWaitTime[MAXPLAYERS+1];

//cvar
int iTimeGame;
int iCvarCredits[2]; //0 - minimum credits | 1 - maximum credits
float fCommission;
int iChangeWrite;
float fWriteTime;
float fWaitTime;

public Plugin myinfo = {
	name        = "[Shop] FlipGame",
	author      = "FLASHER",
	description = "Монетка на кредиты",
	version     = "2.1.1",
	url = "discord: FLASHER#4704"
};

public OnPluginStart ()
{
	RegConsoleCmd ("sm_flip", MainMenu);
	AddCommandListener(Command_Say, "say");
	AddCommandListener(Command_Say, "say_team");
	g_hCookie = RegClientCookie("Shop_FlipGame", "Shop_FlipGame", CookieAccess_Private);
	
	ConVar cvar;
	
	(cvar = CreateConVar("flip_time", "5",	"The time after which the game will be played between the players", _, true, 1.0)).AddChangeHook(ChangeCvar_TimeGame);
	iTimeGame = cvar.IntValue;
	
	(cvar = CreateConVar("flip_maxcredits", "0",	"Maximum credits for a bet [0 - no limit]", _, true, 0.0)).AddChangeHook(ChangeCvar_MaxCredits);
	iCvarCredits[1] = cvar.IntValue;
	
	(cvar = CreateConVar("flip_mincredits", "1",	"Minimum credits for a bet", _, true, 1.0)).AddChangeHook(ChangeCvar_MinCredits);
	iCvarCredits[0] = cvar.IntValue;
	
	(cvar = CreateConVar("flip_percent", "0.0",	"Commission that will be charged on the winnings (In percentage) [0 - no commission]", _, true, 0.0, true, 49.0)).AddChangeHook(ChangeCvar_fCommission);
	fCommission = cvar.FloatValue;
	
	(cvar = CreateConVar("flip_changewrite", "0",	"output type of the game process [Hud - 0 | Chat - 1]", _, true, 0.0, true, 1.0)).AddChangeHook(ChangeCvar_ChangeWrite);
	iChangeWrite = cvar.IntValue;
	
	(cvar = CreateConVar("flip_writetime", "10.0",	"Time to enter a bet into chat", _, true, 1.0)).AddChangeHook(ChangeCvar_fWriteTime);
	fWriteTime = cvar.FloatValue;
	
	(cvar = CreateConVar("flip_waittime", "2.0",	"CD to send offers to other players", _, true, 0.1)).AddChangeHook(ChangeCvar_fWaitTime);
	fWaitTime = cvar.FloatValue;
	
	AutoExecConfig(true, "shop_flipgame", "shop");
}

public void ChangeCvar_TimeGame(ConVar convar, const char[] oldValue, const char[] newValue)
{
	iTimeGame = convar.IntValue;
}
public void ChangeCvar_MaxCredits(ConVar convar, const char[] oldValue, const char[] newValue)
{
	iCvarCredits[1] = convar.IntValue;
}
public void ChangeCvar_MinCredits(ConVar convar, const char[] oldValue, const char[] newValue)
{
	iCvarCredits[0] = convar.IntValue;
}
public void ChangeCvar_fCommission(ConVar convar, const char[] oldValue, const char[] newValue)
{
	fCommission = convar.FloatValue;
}
public void ChangeCvar_fWriteTime(ConVar convar, const char[] oldValue, const char[] newValue)
{
	fWriteTime = convar.FloatValue;
}
public void ChangeCvar_ChangeWrite(ConVar convar, const char[] oldValue, const char[] newValue)
{
	iChangeWrite = convar.IntValue;
}
public void ChangeCvar_fWaitTime(ConVar convar, const char[] oldValue, const char[] newValue)
{
	fWaitTime = convar.FloatValue;
}

public void OnClientCookiesCached(int iClient)
{
	char szValue[64];
	GetClientCookie(iClient, g_hCookie, szValue, sizeof(szValue));
	if(szValue[0])
	{
		new String:sNew[5][128];
		ExplodeString(szValue, ":", sNew, 5, 128, false);
		iStats[iClient][0] = StringToInt(sNew[0]);
		iStats[iClient][1] = StringToInt(sNew[1]);
		iStats[iClient][2] = StringToInt(sNew[2]);
		iStats[iClient][3] = StringToInt(sNew[3]);
		iStats[iClient][4] = StringToInt(sNew[4]);
	}
}

public void OnMapEnd() {
	for(int i = 1; i <= MaxClients; i++) {
		hWriteTimer[i] = INVALID_HANDLE;
	}
}

public Action:MainMenu(client, args)
{
	MoneyGameMenu(client);
	return Plugin_Handled;
}

MoneyGameMenu(client)
{
	Menu menu = new Menu(FlipGameMenu);
	menu.SetTitle("Flip Game\n \n");
	menu.AddItem("", "Start the game");
	
	if(!iStats[client][4]) menu.AddItem("", "Disable suggestions");
	else menu.AddItem("", "Include suggestions");
	
	menu.AddItem("", "My stats");
	menu.ExitButton = true;
	menu.ExitBackButton = false;
	menu.Display(client, 0);
}

ShowStartGameMenu(client)
{
	if(iPreCredits[client][1] > Shop_GetClientCredits(client) || iPreCredits[client][1] == 0 || iPreCredits[client][1] < iCvarCredits[0]) iPreCredits[client][1] = iCvarCredits[0];
	
	Menu menu = new Menu(StartGameHadler);
	menu.SetTitle("Coin\n \nYour bid: %i credits\nCoin side: %s\n \n", iPreCredits[client][1], cFlipCoin[iClientCoin[client][0]]);
	menu.AddItem("", "Change bid");
	menu.AddItem("", "Change the side of the coin\n \n");
	
	if(iPreCredits[client][1] > Shop_GetClientCredits(client)) menu.AddItem("", "Find a player\n \n", 1);
	else menu.AddItem("", "Find a player\n \n");
	
	menu.AddItem("", "Back");
	
	menu.ExitButton = true;
	menu.ExitBackButton = false;
	menu.Display(client, 0);
}

ShowStatsMenu(client)
{
	Menu menu = new Menu(StatsMenu);
	menu.SetTitle("Statistics\n \nNick: %N\nNumber of games: %i\nWins: %i\nDefeats: %i\nCredits earned: %i\nLost credits: %i\n \n", client, iStats[client][0], iStats[client][1], iStats[client][0]-iStats[client][1],iStats[client][2],iStats[client][3]);
	menu.AddItem("", "Back");
	menu.ExitButton = true;
	menu.ExitBackButton = false;
	menu.Display(client, 0);
}

public int StatsMenu(Menu menu, MenuAction action, int client, int param)
{
	if (action == MenuAction_End) 
		delete menu;
	else if (action == MenuAction_Select)
		if(!param) MoneyGameMenu(client);
}

public int StartGameHadler(Menu menu, MenuAction action, int client, int param)
{
	if (action == MenuAction_End) 
		delete menu;
	else if (action == MenuAction_Select)
	{
		if(param == 3) MoneyGameMenu(client);
		else if(param == 0) //Change rate
		{
			CGOPrintToChat(client, "%s Enter your bet amount in chat:", pl_tag);
			Kill_Timer(client);
			hWriteTimer[client] = CreateTimer(fWriteTime, Timer_Write, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
		}
		else if(param == 1) //Change the side of the coin
		{
			if(iClientCoin[client][0]) iClientCoin[client][0] = 0;
			else iClientCoin[client][0] = 1;
			ShowStartGameMenu(client);
		}
		else if(param == 2) //Find a player
		{
			if(!bWaitTime[client]) {
				Menu pmenu = new Menu(ChoicePlayer); 
				pmenu.SetTitle("Select a player\nRate: %i credits:\n \n", iPreCredits[client][1]); 
				decl String:userid[15], String:name[32]; 
				int count = 0;
				for (int i = 1; i <= MaxClients; i++) 
				{
					if (IsClientInGame(i) && !IsFakeClient(i) && Shop_GetClientCredits(i) >= iPreCredits[client][1] && !IsClientInPlay[i] && client != i && !iStats[i][4]) 
					{ 
						IntToString(GetClientUserId(i), userid, 15); 
						GetClientName(i, name, 32); 
						pmenu.AddItem(userid, name); 
						count++;
					}
				}
				
				if(!count) pmenu.AddItem("", "No matching players", 1);
				
				pmenu.ExitButton = true;
				pmenu.ExitBackButton = true;
				pmenu.Display(client, 0); 
			}
			else { 
				CGOPrintToChat(client, "%s Not so fast! Expect...", pl_tag);
				ShowStartGameMenu(client);
			}
		}
	}
}

public Action:Timer_Write(Handle:timer, any:userid){
	int iClient = GetClientOfUserId(userid);
	if(iClient > 0)
		CGOPrintToChat(iClient, "%s Value input time out.", pl_tag);
	hWriteTimer[iClient] = INVALID_HANDLE;
}

stock Kill_Timer(client){
	if(hWriteTimer[client] != INVALID_HANDLE){
		KillTimer(hWriteTimer[client]);
		hWriteTimer[client] = INVALID_HANDLE;
	}
}

public int ChoicePlayer(Menu pmenu, MenuAction action, int client, int param)
{
	if (action == MenuAction_End) 
		delete pmenu;
	else if (action == MenuAction_Select)
	{
		if (Shop_GetClientCredits(client) >= iPreCredits[client][1]) //Does the player still have credits
		{
			if(!IsClientInPlay[client]) //If the player is not yet in the game
			{
				CGOPrintToChat(client, "%s Proposal sent", pl_tag);
				
				//Ставим кд
				bWaitTime[client] = true;
				CreateTimer(fWaitTime, Timer_Wait, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
				
				decl String:userid[15]; 
				pmenu.GetItem(param, userid, 15); 
				int target = GetClientOfUserId(StringToInt(userid)); 
				if (target > 0) 
				{
					if(!IsClientInPlay[target]) //Checking if the target is in the game
					{
						if(Shop_GetClientCredits(target) >= iPreCredits[client][1]) //Does he have credits
						{
							iPreCredits[target][2] = iPreCredits[client][1]; //We fix the rate

							Menu menu = new Menu(TargetFlipMenu);
							
							decl String:sBuffer[128];
							Format(sBuffer, sizeof(sBuffer), "%i", client);
							
							menu.SetTitle("Coin\n \nOffer to play with a player: %N\nRate: %i credits\n \n", client, iPreCredits[target][2]); 
							menu.AddItem(sBuffer, "To accept the offer");
							menu.AddItem(sBuffer, "To refuse the offer");
							menu.ExitButton = true;
							menu.ExitBackButton = false;
							menu.Display(target, 0);
						}
						else
						{
							CGOPrintToChat(client, "%s The player no longer has enough credits", pl_tag);
							ShowStartGameMenu(client); 
						}
					}
					else
					{
						CGOPrintToChat(client, "%s Player accepted a game with another player", pl_tag);
					}
				}
				else
				{				
					CGOPrintToChat(client, "%s Player logged out", pl_tag); 
					ShowStartGameMenu(client); 
				}
			}
			else
			{
				CGOPrintToChat(client, "%s You are in the game", pl_tag);
				ShowStartGameMenu(client);
			}
		}
		else
		{
			CGOPrintToChat(client, "%s You don't have enough credits anymore", pl_tag);
			ShowStartGameMenu(client);
		}
	}
	else if(action == MenuAction_Cancel)
	{
		if(param == MenuCancel_ExitBack)
		{
			ShowStartGameMenu(client);
		}
	}
}

public Action:Timer_Wait(Handle:timer, any:userid){
	int iClient = GetClientOfUserId(userid);
	if(iClient > 0)
		bWaitTime[iClient] = false;
}

public int TargetFlipMenu(Menu pmenu, MenuAction action, int target, int param)
{
	if (action == MenuAction_End) 
		delete pmenu;
	else if (action == MenuAction_Select)
	{
		decl String:sId[15]; 
		pmenu.GetItem(param, sId, 15); 
		int Inviter = StringToInt(sId);
		
		if(param) 
		{
			if(IsClientInGame(Inviter)) CGOPrintToChat(Inviter, "%s {BLUE}%N {DEFAULT}refused to play", pl_tag, target);
			iPreCredits[target][2] = 0;
		}
		else
		{
			if(IsClientInGame(Inviter)) // Check if the player is on the server
			{
				if(!IsClientInPlay[Inviter]) //If a player is not yet in a game with another player
				{
					if(Shop_GetClientCredits(Inviter) >= iPreCredits[target][2]) //Does the player have credits
					{
						if(Shop_GetClientCredits(target) >= iPreCredits[target][2]) //Does the target have credits
						{
							CGOPrintToChat(Inviter, "%s Player {BLUE}%N {DEFAULT}agreed", pl_tag, target);
						
							//Players in the game
							IsClientInPlay[Inviter] = true;
							IsClientInPlay[target] = true;
							
							//Game statistics
							iStats[Inviter][0]++;
							iStats[target][0]++;
							
							//Assigning the side of the target coin
							if(!iClientCoin[Inviter][0]) iClientCoin[target][1] = 1;
							else iClientCoin[target][1] = 0;
							//Assigning the side of the coin to ourselves
							iClientCoin[Inviter][1] = iClientCoin[Inviter][0];
							
							//We withdraw credits
							Shop_SetClientCredits(Inviter, Shop_GetClientCredits(Inviter) - iPreCredits[target][2]);
							Shop_SetClientCredits(target, Shop_GetClientCredits(target) - iPreCredits[target][2]);
							
							//Equating rates
							iPreCredits[Inviter][2] = iPreCredits[target][2];
							
							//Statistics: Lost credits
							iStats[Inviter][3] += iPreCredits[target][2];
							iStats[target][3] += iPreCredits[target][2];
							
							//Launch the game
							iFlipTime[Inviter] = iTimeGame; //Timer Time
							new Handle:datapack = CreateDataPack();
							WritePackCell(datapack, Inviter);
							WritePackCell(datapack, target);
							
							//Informing players about their side of the coin in the chat
							CGOPrintToChat(Inviter, "%s Your side of the coin: {LIGHTGREEN}%s", pl_tag, cFlipCoin[iClientCoin[Inviter][1]]);
							CGOPrintToChat(target, "%s Your side of the coin: {LIGHTGREEN}%s", pl_tag, cFlipCoin[iClientCoin[target][1]]);
							
							CreateTimer(1.0, FlipTime, datapack, TIMER_REPEAT);	
						}
						else
						{
							CGOPrintToChat(target, "%s You don't have enough credits", pl_tag);
						}
					}
					else
					{
						CGOPrintToChat(target, "%s has {BLUE}%N {DEFAULT}no more credits", pl_tag, Inviter);
					}
				}
				else
				{
					CGOPrintToChat(target, "%s {BLUE}%N {DEFAULT}is already in another game", pl_tag, Inviter);
				}
			}
			else
			{
				CGOPrintToChat(target, "%s The player has already logged out", pl_tag);
			}
		}
	}
}

public Action:FlipTime(Handle:timer, Handle:datapack)
{
	ResetPack(datapack, false);
	int inviter = ReadPackCell(datapack);
	int target = ReadPackCell(datapack);
	
	if(iFlipTime[inviter]) //The game is in progress
	{
		if(IsClientInGame(inviter) && IsClientInGame(target))
		{
			if(!iChangeWrite)
			{
				char g_mText[1028];
				Format(g_mText, sizeof(g_mText), "<pre><span class='fontSize-m'>By you: <font color='#FFA500'>%s</font>\nAt stake: <font color='#FFA500'>%i</font> credit(s)\nBefore the game <font color='#FFA500'>%i</font> sec.</span></pre>", cFlipCoin[iClientCoin[inviter][1]], iPreCredits[target][2]*2, iFlipTime[inviter]);
				PrintHintText(inviter, g_mText);
				Format(g_mText, sizeof(g_mText), "<pre><span class='fontSize-m'>By you: <font color='#FFA500'>%s</font>\nAt stake: <font color='#FFA500'>%i</font> credit(s)\nBefore the game <font color='#FFA500'>%i</font> sec.</span></pre>", cFlipCoin[iClientCoin[target][1]], iPreCredits[target][2]*2, iFlipTime[inviter]);
				PrintHintText(target, g_mText);
			}
			else //For those few who have a busy hud
			{
				if(iFlipTime[inviter] == iTimeGame)
				{
					CGOPrintToChat(inviter, "%s Before choosing a winner: {LIGHTGREEN}%i {DEFAULT}сек.", pl_tag, iFlipTime[inviter]);
					CGOPrintToChat(target, "%s Before choosing a winner: {LIGHTGREEN}%i {DEFAULT}сек.", pl_tag, iFlipTime[inviter]);
				}
			}
		}
		else //If someone is out of the game - choose the winner
		{
			if(!IsClientInGame(inviter)) PlayerWin(target, inviter);
			else if (!IsClientInGame(target)) PlayerWin(inviter, target);
			CloseHandle(datapack);
			return Plugin_Stop;
		}
		
		iFlipTime[inviter]--; //Timer
		return Plugin_Continue;
	}
	else //Choosing a winner
	{
		if(!iChangeWrite)
		{
			//Roulette Launch
			UpTimer[inviter] = 0.03;
			UTimer[inviter] = 20;
			CreateTimer(0.03, flipwin, datapack);
		}
		else //For those few who have a busy hud
		{
			int iChance = GetRandomInt(0, 1); //Super random
			
			//We inform the players what has dropped out
			if(IsClientInGame(inviter))
				CGOPrintToChat(inviter, "%s We have {BLUE}%s", pl_tag, cFlipCoin[iChance]);
			if(IsClientInGame(target))
				CGOPrintToChat(target, "%s We have {BLUE}%s", pl_tag, cFlipCoin[iChance]);
			
			//Determining the winner
			if(iClientCoin[inviter][1] == iChance) PlayerWin(inviter, target);
			else PlayerWin(target, inviter);
			CloseHandle(datapack);
		}
		return Plugin_Stop;
	}
}

public Action flipwin(Handle:timer, Handle:datapack)
{
	ResetPack(datapack, false);
	int inviter = ReadPackCell(datapack);
	int target = ReadPackCell(datapack);
	
	if(IsClientInGame(inviter) && IsClientInGame(target))
	{
		int iChance = GetRandomInt(0, 1); //Super random
		if(iChance)
		{
			USussces[inviter][3] = cFlipCoin[1];
			if(UTimer[inviter] == 3) iWin[inviter] = 1;
		}
		else
		{
			USussces[inviter][3] = cFlipCoin[0];
		}
		
		//Assigning colors
		if(iChance == iClientCoin[inviter][1]) sColor[inviter][3] = "<font color='#7CFC00'>";
		else sColor[inviter][3] = "<font color='#DC143C'>";
			
		if(iChance == iClientCoin[target][1]) sColor[target][3] = "<font color='#7CFC00'>";
		else sColor[target][3] = "<font color='#DC143C'>";
		
		//Displaying a message to the center
		PrintCenterText(inviter, "<pre><span class='fontSize-m'>%s%s</font>\n%s%s</font>\n%s%s ◄◄◄</font>\n%s%s</font></span></pre>", sColor[inviter][3], USussces[inviter][3], sColor[inviter][2], USussces[inviter][2],sColor[inviter][1], USussces[inviter][1],sColor[inviter][0], USussces[inviter][0]);
		ClientCommand(inviter, "playgamesound ui/csgo_ui_crate_item_scroll.wav");
		
		PrintCenterText(target, "<pre><span class='fontSize-m'>%s%s</font>\n%s%s</font>\n%s%s ◄◄◄</font>\n%s%s</font></span></pre>",sColor[target][3], USussces[inviter][3],sColor[target][2], USussces[inviter][2],sColor[target][1], USussces[inviter][1],sColor[target][0], USussces[inviter][0]);
		ClientCommand(target, "playgamesound ui/csgo_ui_crate_item_scroll.wav");
		
		for(int i = 1; i <= 3; ++i)
		{
			sColor[inviter][i-1] = sColor[inviter][i];
			sColor[target][i-1] = sColor[target][i];
			USussces[inviter][i-1] = USussces[inviter][i];
		}
		
		UTimer[inviter]--;
		
		if(!UTimer[inviter])
		{
			CGOPrintToChat(inviter, "%s We have {BLUE}%s", pl_tag, cFlipCoin[iWin[inviter]]);
			CGOPrintToChat(target, "%s We have {BLUE}%s", pl_tag, cFlipCoin[iWin[inviter]]);
			
			//Determining the winner
			if(iClientCoin[inviter][1] == iWin[inviter]) PlayerWin(inviter, target);
			else PlayerWin(target, inviter);
				
			iWin[inviter] = 0;
			CloseHandle(datapack);
			return Plugin_Stop;
		}
		//To speed up the timer
		if(UTimer[inviter] <= 7)
		{
			UpTimer[inviter] += 0.15;
		}
		
		CreateTimer(UpTimer[inviter], flipwin, datapack);
		return Plugin_Stop;
	}
	else //If someone is out of the game - choose the winner
	{
		if(!IsClientInGame(inviter)) PlayerWin(target, inviter);
		else if (!IsClientInGame(target)) PlayerWin(inviter, target);
		CloseHandle(datapack);
		return Plugin_Stop;
	}
}

PlayerWin(winner, looser)
{
	int CreditsWin; //Single player bet
	if(iPreCredits[winner][2]) CreditsWin = iPreCredits[winner][2];
	else CreditsWin = iPreCredits[looser][2];
	int CreditsWinCommission = RoundFloat((CreditsWin * 2) - (CreditsWin * 2 * fCommission / 100)); //Full winnings with commission
		
	if(IsClientInGame(winner))
	{
		iStats[winner][1]++; //Statistics: victories
		iStats[winner][2] += CreditsWinCommission - CreditsWin; //Statistics: Credits Earned
		iStats[winner][3] -= CreditsWin; //Statistics: return loss
		
		if(!IsClientInGame(looser))
		{
			Shop_SetClientCredits(winner, Shop_GetClientCredits(winner) + CreditsWin);
			CGOPrintToChat(winner, "%s The player exited. You won! You got it back {LIGHTGREEN}%i {DEFAULT}credits", pl_tag, CreditsWin);
		}
		else
		{
			Shop_SetClientCredits(winner, Shop_GetClientCredits(winner) + CreditsWinCommission);
			CGOPrintToChat(winner, "%s You've earned {LIGHTGREEN}%i {DEFAULT}credits", pl_tag, CreditsWinCommission);
		}
		
		IsClientInPlay[winner] = false;
	}
	if(IsClientInGame(looser))
	{
		CGOPrintToChat(looser, "%s You lost {LIGHTGREEN}%i {DEFAULT}credits", pl_tag, CreditsWin);
		IsClientInPlay[looser] = false;
	}
	
	if(IsClientInGame(looser) && IsClientInGame(winner))
	{
		CGOPrintToChatAll("%s {LIGHTGREEN}%N {DEFAULT}won {LIGHTGREEN}%N {DEFAULT}and earned {LIGHTGREEN}%i {DEFAULT}credits", pl_tag, winner, looser, CreditsWinCommission);
	}
}

public int FlipGameMenu(Menu menu, MenuAction action, int client, int param)
{
	if (action == MenuAction_End) 
	{ 
		delete menu;
	}
	else if (action == MenuAction_Select)
	{	
		if(!param) ShowStartGameMenu(client);
		else if (param == 2) 
		{
			ShowStatsMenu(client);
		}
		else if(param == 1)
		{
			if(!iStats[client][4]) iStats[client][4] = 1;
			else iStats[client][4] = 0;
			
			MoneyGameMenu(client);
		}
	}
}

public Action Command_Say(int client, const char[] command, int argc)
{
	if(client > 0 && client <= MaxClients)
	{
		char text[64];
		if (!GetCmdArgString(text, sizeof(text)) || !text[0])
		{
			return Plugin_Continue;
		}
		if(hWriteTimer[client] != INVALID_HANDLE) {
			Kill_Timer(client);
			StripQuotes(text);
			TrimString(text);
			
			int PreCredits = StringToInt(text);
			if(PreCredits > 0)
			{
				if(Shop_GetClientCredits(client) >= PreCredits)
				{
					if(PreCredits <= iCvarCredits[1] || iCvarCredits[1] == 0) //Checking for the maximum bet
					{
						if(PreCredits >= iCvarCredits[0]) //Minimum bet check
						{
							CGOPrintToChat(client, "%s You changed your bid to {LIGHTGREEN}%i {DEFAULT}credits", pl_tag, PreCredits);
							iPreCredits[client][1] = PreCredits;
						}
						else
						{
							CGOPrintToChat(client, "%s Error! Minimum bet amount {LIGHTGREEN}%i {DEFAULT}credits", pl_tag, iCvarCredits[0]);
						}
					}
					else
					{
						CGOPrintToChat(client, "%s Error! Maximum bet amount {LIGHTGREEN}%i {DEFAULT}credits", pl_tag, iCvarCredits[1]);
					}
				}
				else
				{
					CGOPrintToChat(client, "%s Error! You don't have enough credit", pl_tag);
				}
			}
			else
			{
				CGOPrintToChat(client, "%s Invalid number", pl_tag);
			}
			ShowStartGameMenu(client);
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

public OnClientDisconnect(iClient) // We catch the player's exit
{
	//We save statistics
	decl String:sBuffer[128];
	Format(sBuffer, sizeof(sBuffer), "%i:%i:%i:%i:%i", iStats[iClient][0],iStats[iClient][1],iStats[iClient][2],iStats[iClient][3],iStats[iClient][4]);
	SetClientCookie(iClient, g_hCookie, sBuffer);
	IsClientInPlay[iClient] = false; //Player not in play - coin
	bWaitTime[iClient] = false;
}