#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <csgo_colors>
#include <shop>

#pragma semicolon 1

public Plugin:myinfo = 
{
	name = "VertexLOT",
	author = "qq+IceBoom",
	description = "",
	version = "1.2",
	url = "serveraksgo.ru/"
};

#define DMG_FALL (1 << 5)
new Handle:g_LotPanel2;
new Handle:g_LotHistory_Trie2;
new ScrollTimes[MAXPLAYERS + 1];
new WinNumber[MAXPLAYERS + 1];
new bool:NextStep[MAXPLAYERS + 1] = false;
new bool:Podkrutka[MAXPLAYERS + 1] = false;

int g_iCredits[14];

public OnPluginStart()
{
	g_LotHistory_Trie2 = CreateTrie();
	
	RegConsoleCmd("sm_lot", lotx);
	
	RegAdminCmd("sm_rlot", Command_RemoveTrie2, ADMFLAG_GENERIC, "sm_rlot");
	RegAdminCmd("sm_droplot", Command_RemoveTrie3, ADMFLAG_ROOT, "sm_droplot <#userid|name>");
	RegAdminCmd("sm_podkrutka_lot", Command_PodkrutkaLot, ADMFLAG_ROOT);
	
	
	g_LotPanel2 = CreatePanel();
	DrawPanelItem(g_LotPanel2, "Да, купить билет, вдруг повезет");
	DrawPanelItem(g_LotPanel2, "Не-не-не, я отказываюсь участвовать");
	DrawPanelItem(g_LotPanel2, "Посмотреть шансы на выпадение\n \n");
	DrawPanelItem(g_LotPanel2, "Выход");
	SetPanelCurrentKey(g_LotPanel2, 10);
	
	
	new Handle:kv = CreateKeyValues("lotshop");	
	FileToKeyValues(kv, "addons/sourcemod/configs/lotshop.ini");
	KvJumpToKey(kv,	"lot", true);	
	g_iCredits[0] = KvGetNum(kv,"0");
	g_iCredits[1] = KvGetNum(kv,"1-250");
	g_iCredits[2] = KvGetNum(kv,"250-500");
	g_iCredits[3] = KvGetNum(kv,"return1");
	g_iCredits[4] = KvGetNum(kv,"600-700");
	g_iCredits[5] = KvGetNum(kv,"700-800");
	g_iCredits[6] = KvGetNum(kv,"800-850");
	g_iCredits[7] = KvGetNum(kv,"850-900");
	g_iCredits[8] = KvGetNum(kv,"900-996");
	g_iCredits[9] = KvGetNum(kv,"997");
	g_iCredits[10] = KvGetNum(kv,"998");
	g_iCredits[11] = KvGetNum(kv,"999");
	g_iCredits[12] = KvGetNum(kv,"return2");
	g_iCredits[13] = KvGetNum(kv,"ticket");
	KvRewind(kv);
	
	CloseHandle(kv);
}

public Action:Command_PodkrutkaLot(iClient, args)
{
	Select_PL_MENU(iClient);
}

Select_PL_MENU(iClient)
{
	new Handle:menu = CreateMenu(Select_PL);
	SetMenuTitle(menu, "Выберите Игрока:");
	decl String:userid[15], String:name[64];
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			IntToString(GetClientUserId(i), userid, 15);
			GetClientName(i, name, 64);
			if(StrContains(name, "GOTV", false) < 0)
			{
				AddMenuItem(menu, userid, name);
			}
		}
	}
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, iClient, 0);
}

public Select_PL(Handle:menu, MenuAction:action, iClient, option)
{
	if (action == MenuAction_Select)
	{
		decl String:userid[15];
		GetMenuItem(menu, option, userid, 15);
		new u = StringToInt(userid);
		new target = GetClientOfUserId(u);
		if (target)
		{
			NextStep[target] = true;
			CGOPrintToChat(iClient, "{GREEN}Вы дали игроку {BLUE}%N {GREEN}подкрутку в !lot", target);
		}
		else 
		{
			CGOPrintToChat(iClient, "{GREEN}Игрок не найден (вышел с сервера)");
		}
	}
	else if (action == MenuAction_End) CloseHandle(menu);
}

public Action:lotx(client, args)
{
	if (client > 0 && args < 1) {
		char steamid[28];
		int lasttime;
		if (GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid)) && GetTrieValue(g_LotHistory_Trie2, steamid, lasttime)) {
			new sec = GetTime() - lasttime;
			if (sec < 300) {
				sec = 300 - sec;
				CGOPrintToChat(client, "{RED}[Lot]{GRAY} Лотерея доступна 1 раз в 5 минут [Осталось: %d мин. и %02d сек.]", sec / 60, sec % 60);
				return Plugin_Handled;
			} else
				RemoveFromTrie(g_LotHistory_Trie2, steamid);
		}
		wS_ShowLotPanel2(client);
	}
	
	return Plugin_Handled;
}

public Action:Command_RemoveTrie2(client, args)
{
	decl String:steamid[28];
	GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
	RemoveFromTrie(g_LotHistory_Trie2, steamid);
	ScrollTimes[client] = 0;
	
	return Plugin_Handled;
}

public Action:Command_RemoveTrie3(client, args)
{
	if(args == 1)
	{
		decl String:arg[65];
		GetCmdArg(1, arg, sizeof(arg));

		decl String:target_name[MAX_TARGET_LENGTH];
		decl target_list[MAXPLAYERS], target_count, bool:tn_is_ml;

		if ((target_count = ProcessTargetString(
			arg,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_CONNECTED|COMMAND_FILTER_NO_BOTS,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
		{
			ReplyToCommand(client, "[SM] No matching client");
			return Plugin_Handled;
		}

		for (new i = 0; i < target_count; i++)
		{
			decl String:steamid[28];
			GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
			RemoveFromTrie(g_LotHistory_Trie2, steamid);
			ScrollTimes[client] = 0;
		}
	}
	
	return Plugin_Handled;
}

public g_LotMenu2_CallBack(Handle:panel, MenuAction:action, client, item)
{
	if (action == MenuAction_Select) {
		if (item == 1) {
			if (Shop_GetClientCredits(client) > g_iCredits[13] - 1)
			{
				//Store_SetClientCredits(client, Store_GetClientCredits(client) - 1500);
				Shop_TakeClientCredits(client, g_iCredits[13]);
				iEx_Start(client);
				decl String:steamid[28];
				if (GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid)))
					SetTrieValue(g_LotHistory_Trie2, steamid, GetTime());
			} else
				PrintToChat(client," \x04[Lot]\x02 У вас не хватает %d кредитов для игры!", g_iCredits[13] - Shop_GetClientCredits(client));
		} else
			if (item == 3)
			{
				PrintToChat(client, " \x04[Lot]\x02 000 -> Шанс Выиграть 500 Кр.");
				PrintToChat(client, " \x04[Lot]\x02 001-250 -> Шанс Проиграть 100 кр.");
				PrintToChat(client, " \x04[Lot]\x02 250-500 -> Шанс Выиграть 400 Кр.");
				PrintToChat(client, " \x04[Lot]\x02 501-600 -> Шанс Вернуть ставку.");
				PrintToChat(client, " \x04[Lot]\x02 601-700 -> Шанс Выиграть 550 Кр.");
				PrintToChat(client, " \x04[Lot]\x02 701-800 -> Шанс Проиграть 300 кр.");
				PrintToChat(client, " \x04[Lot]\x02 801-850 -> Шанс Выиграть 750 кр.");
				PrintToChat(client, " \x04[Lot]\x02 851-900 -> Шанс Выиграть 900 кр.");
				PrintToChat(client, " \x04[Lot]\x02 901-996 -> Шанс Проиграть 700 кр.");
				PrintToChat(client, " \x04[Lot]\x02 997 -> Шанс Выиграть 2000 Кр.");
				PrintToChat(client, " \x04[Lot]\x02 998 -> Шанс Выиграть 3000 Кр.");	
				PrintToChat(client, " \x04[Lot]\x02 999 -> Шанс Выиграть 5000 Кр.\n \n");
			}
	}
}

iEx_Start(client)
{
	
	new FakeNumber = GetRandomInt(0,999);
	if(Podkrutka[client]) FakeNumber = 999;
	new Handle:panel = CreatePanel(); 
	SetPanelTitle(panel, "Ящик Рандома:\n \n");
	char Message[128], Message2[128], Message3[128];
	
	Format(Message, 128, "█░░░░░░░░░█");
	Format(Message2, 128, "░░░░░░░░░░░");
	
	DrawPanelText(panel, Message);
	DrawPanelText(panel, Message2);
	
	if(FakeNumber < 10)
		Format(Message3, 128, "░░░░00%d░░░░",FakeNumber);
	else
		if(FakeNumber > 9 && FakeNumber < 100)
			Format(Message3, 128, "░░░░0%d░░░░",FakeNumber);
		else
			Format(Message3, 128, "░░░░%d░░░░",FakeNumber);

	DrawPanelText(panel, Message3);
	DrawPanelText(panel, Message2);
	DrawPanelText(panel, Message);
	SendPanelToClient(panel, client, Select_None, 10); 
	CloseHandle(panel);
	
	if(ScrollTimes[client] == 0)
		ClientCommand(client, "playgamesound ui/csgo_ui_crate_open.wav");

	if(ScrollTimes[client] < 20) {
		CreateTimer(0.15, Timer_Next,client);
		ScrollTimes[client] += 1;
		ClientCommand(client, "playgamesound ui/csgo_ui_crate_item_scroll.wav");
	} else
		// 20 < ScrollTimes < 30
		if(ScrollTimes[client] < 30) {
			new Float:AddSomeTime = 0.14;
			AddSomeTime += 0.01*ScrollTimes[client]/3;
			CreateTimer(AddSomeTime, Timer_Next,client);
			ScrollTimes[client] += 1;
			ClientCommand(client, "playgamesound ui/csgo_ui_crate_item_scroll.wav");
		} else
			// ScrollTimes == 30
			if(ScrollTimes[client] == 30) {
				if(GetRandomInt(0,1)) {
					ClientCommand(client, "playgamesound ui/csgo_ui_crate_item_scroll.wav");
					ScrollTimes[client] += 1;
					CreateTimer(2.0, Timer_Next, client);
					if(NextStep[client]) Podkrutka[client] = true;
				} else {
					ClientCommand(client, "playgamesound ui/csgo_ui_crate_item_scroll.wav");
					CreateTimer(2.0, Timer_Finishing, client);
					WinNumber[client] = FakeNumber;
					ScrollTimes[client] = 0;
				}
			// ScrollTimes > 30
			} else {
				ClientCommand(client, "playgamesound ui/csgo_ui_crate_item_scroll.wav");
				CreateTimer(2.0, Timer_Finishing, client);
				WinNumber[client] = FakeNumber;
				ScrollTimes[client] = 0;
			}
}

public Action Timer_Finishing(Handle timer, any client)
{
	if (IsClientInGame(client))
		iEx_Win(client, WinNumber[client]);
}

iEx_Win(client, Number)
{
	if(IsClientInGame(client)) {
		if(Number == 0) {
			PrintToChatAll(" \x04 [Lot]\x02 Игроку \x04\"%N\"\x02 Выпало число:\x0B %d", client, Number);
			PrintToChatAll(" \x04 [Lot]\x02 Ему посчастливилось выиграть: \x0B%i Кредитов!!!",g_iCredits[0]);
			ClientCommand(client, "playgamesound ui/item_drop6_ancient.wav");
			Shop_GiveClientCredits(client, g_iCredits[0],IGNORE_FORWARD_HOOK);
		} else if(Number > 0 && Number <= 250) {
			PrintToChatAll(" \x04 [Lot]\x02 Игроку \x04\"%N\"\x02 Выпало число:\x0B %d",client,Number);
			PrintToChatAll(" \x04 [Lot]\x02 \x0BПроиграл %i кредитов, Сочувствуем вашей потере!",g_iCredits[1]);
			ClientCommand(client, "playgamesound music/skog_01/lostround.mp3");
			Shop_TakeClientCredits(client, g_iCredits[1],IGNORE_FORWARD_HOOK);
		} else if(Number > 250 && Number <= 500) {
			PrintToChatAll(" \x04 [Lot]\x02 Игроку \x04\"%N\"\x02 Выпало число:\x0B %d",client,Number);
			PrintToChatAll(" \x04 [Lot]\x02 Ему посчастливилось выиграть: \x0B%i Кредитов!!!",g_iCredits[2]);
			ClientCommand(client, "playgamesound ui/item_drop2_uncommon.wav");
			Shop_GiveClientCredits(client, g_iCredits[2],IGNORE_FORWARD_HOOK);
		} else if(Number > 500 && Number <= 600) {
			ClientCommand(client, "playgamesound ui/item_drop1_common.wav");
			PrintToChatAll(" \x04 [Lot]\x02 Игроку \x04\"%N\"\x02 Выпало число:\x0B %d",client,Number);
			PrintToChatAll(" \x04 [Lot]\x02 Ему удалось избежать потери и \x0BВернул кредиты");
			Shop_GiveClientCredits(client, g_iCredits[3],IGNORE_FORWARD_HOOK);
		} else if(Number > 600 && Number <= 700) {
			PrintToChatAll(" \x04 [Lot]\x02 Игроку \x04\"%N\"\x02 Выпало число:\x0B %d",client,Number);
			PrintToChatAll(" \x04 [Lot]\x02 Ему посчастливилось выиграть: \x0B%i Кредитов!!!",g_iCredits[4]);
			ClientCommand(client, "playgamesound ui/item_drop2_uncommon.wav");
			Shop_GiveClientCredits(client, g_iCredits[4],IGNORE_FORWARD_HOOK);
		} else if(Number >700 && Number <=800) {
			PrintToChatAll(" \x04 [Lot]\x02 Игроку \x04\"%N\"\x02 Выпало число:\x0B %d",client,Number);
			PrintToChatAll(" \x04 [Lot]\x02 \x0BПроиграл %i кредитов, Сочувствуем вашей потере!",g_iCredits[5]);
			ClientCommand(client, "playgamesound music/skog_01/lostround.mp3");
			Shop_TakeClientCredits(client, g_iCredits[5],IGNORE_FORWARD_HOOK);
		} else if(Number > 800 && Number <= 850) {
			PrintToChatAll(" \x04 [Lot]\x02 Игроку \x04\"%N\"\x02 Выпало число:\x0B %d",client,Number);
			PrintToChatAll(" \x04 [Lot]\x02 Ему посчастливилось выиграть: \x0B%i Кредитов!!!",g_iCredits[6]);
			ClientCommand(client, "playgamesound ui/item_drop2_uncommon.wav");
			Shop_GiveClientCredits(client, g_iCredits[6],IGNORE_FORWARD_HOOK);
		} else if(Number > 850 && Number <= 900) {
			PrintToChatAll(" \x04 [Lot]\x02 Игроку \x04\"%N\"\x02 Выпало число:\x0B %d",client,Number);
			PrintToChatAll(" \x04 [Lot]\x02 Ему посчастливилось выиграть: \x0B%i Кредитов!!!",g_iCredits[7]);
			ClientCommand(client, "playgamesound ui/item_drop2_uncommon.wav");
			Shop_GiveClientCredits(client, g_iCredits[7],IGNORE_FORWARD_HOOK);
		} else if(Number >900 && Number <=996) {
			PrintToChatAll(" \x04 [Lot]\x02 Игроку \x04\"%N\"\x02 Выпало число:\x0B %d",client,Number);
			PrintToChatAll(" \x04 [Lot]\x02 \x0BПроиграл %i кредитов, Сочувствуем вашей потере!",g_iCredits[8]);
			ClientCommand(client, "playgamesound music/skog_01/lostround.mp3");
			Shop_TakeClientCredits(client, g_iCredits[8],IGNORE_FORWARD_HOOK);
		} else if(Number == 997) {
			PrintToChatAll(" \x04 [Lot]\x02 Игроку \x04\"%N\"\x02 Выпало число:\x0B %d",client,Number);
			PrintToChatAll(" \x04 [Lot]\x02 Ему посчастливилось выиграть: \x0B%i Кредитов!!!",g_iCredits[9]);
			ClientCommand(client, "playgamesound ui/item_drop3_rare.wav");
			Shop_GiveClientCredits(client, g_iCredits[9],IGNORE_FORWARD_HOOK);
		} else if(Number == 998) {
			PrintToChatAll(" \x04 [Lot]\x02 Игроку \x04\"%N\"\x02 Выпало число:\x0B %d",client,Number);
			PrintToChatAll(" \x04 [Lot]\x02 Ему посчастливилось выиграть: \x0B%i Кредитов!!!",g_iCredits[10]);
			ClientCommand(client, "playgamesound ui/item_drop3_rare.wav");
			Shop_GiveClientCredits(client, g_iCredits[10],IGNORE_FORWARD_HOOK);
		} else if(Number == 999) {
			PrintToChatAll(" \x04 [Lot]\x02 Игроку \x04\"%N\"\x02 Выпало число:\x0B %d",client,Number);
			PrintToChatAll(" \x04 [Lot]\x02 Ему посчастливилось выиграть: \x0B%i Кредитов!!!",g_iCredits[11]);
			ClientCommand(client, "playgamesound ui/item_drop6_ancient.wav");	
			Shop_GiveClientCredits(client, g_iCredits[11],IGNORE_FORWARD_HOOK);
		} else {
			ClientCommand(client, "playgamesound ui/item_drop1_common.wav");
			PrintToChatAll(" \x04 [Lot]\x02 Игроку \x04\"%N\"\x02 Выпало число:\x0B %d",client,Number);
			PrintToChatAll(" \x04 [Lot]\x02 Ему удалось избежать потери и \x0BВернул кредиты");
			Shop_GiveClientCredits(client, g_iCredits[12],IGNORE_FORWARD_HOOK);
		}
		if(NextStep[client]) NextStep[client] = false;
		if(Podkrutka[client]) Podkrutka[client] = false;
	}
}

public Action:Timer_Next(Handle:timer, any:client)
{
	if (IsClientInGame(client))
		iEx_Start(client);
}

public Select_None(Handle:panel, MenuAction:action, client, option) 
{
	// nothing 
}

wS_ShowLotPanel2(client)
{
	SetPanelTitle(g_LotPanel2, "[Lot] Поехали?\n \n");
	SendPanelToClient(g_LotPanel2, client, g_LotMenu2_CallBack, 0);
}