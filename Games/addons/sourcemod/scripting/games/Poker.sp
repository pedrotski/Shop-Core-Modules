#define NULL		0
#define SET			1
#define FULLHOUSE	2
#define QUAD		3
#define STRAIGHT	4
#define POKER		5

char Cmb[][] =
{
	"Chance",
	"Set",
	"Full house",
	"Square",
	"Straight",
	"Poker"
};

int PThrow[MAXPLAYERS+1];
int PCubes[MAXPLAYERS+1];
int PCube[MAXPLAYERS+1][5];
int PCubeFix[MAXPLAYERS+1][5];

void StartGame_Poker(int client1)
{
	int client2 = GetClientEnemy(client1);
	if (!IsClientPlay(client2))
	{
		return;
	}

	ShowMenu_GamePoker(client1, false, true);
	ShowMenu_GamePoker(client2, false, true);

	if (!IsValidClient(client1) || !IsValidClient(client2))
	{
		ResetGame(client1, client2);
	}
}

void ShowMenu_GamePoker(int client, bool Throw = false, bool start = false)
{
	if (start)
	{
		PrintToChat(client, "%s The game has begun.", GPREFIX);

		PThrow[client] = 2;
		PCubes[client] = 0;

		for (new i = 0; i < 5; i++)
		{
			PCube[client][i] = 0;
		}

		CreateTimer(1.0, HudGame_Poker, client, TIMER_REPEAT);
	}

	if (PCubes[client] == 5)
	{
		return;
	}

	Time[client] = GameTime;

	Menu menu = new Menu(GamePoker_MenuHandler);
	menu.SetTitle("%s:\nThrows left: %i\n \n", GameName[1], PThrow[client]);

	char buffer1[32];
	char buffer2[32];

	int style;
	if (PThrow[client] <= 0)
	{
		style = ITEMDRAW_DISABLED;
	}

	menu.AddItem("10", "Reroll\n \n", style);

	for (new i = 0; i < 5; i++)
	{
		if (PCube[client][i] != -1)
		{
			IntToString(i, buffer1, sizeof(buffer1));

			if (!Throw)
			{
				int cube = GetRandomInt(1, 6);
				PCube[client][i] = cube;
				FormatEx(buffer2, sizeof(buffer2), "  [%i]", cube);
			}
			else
			{
				FormatEx(buffer2, sizeof(buffer2), "  [%i]", PCube[client][i]);
			}

			menu.AddItem(buffer1, buffer2);
		}
	}

	menu.ExitButton = false;
	menu.Display(client, GameTime);
}

public int GamePoker_MenuHandler(Menu menu, MenuAction action, int client1, int param)
{
	int client2;
	if (client1 > 0)
	{
		client2 = GetClientEnemy(client1);
	}

	if(action == MenuAction_Select)
	{
		char info[32];
		GetMenuItem(menu, param, info, sizeof(info));
		int cube = StringToInt(info);

		if (cube == 10)
		{
			PThrow[client1] -= 1;

			ShowMenu_GamePoker(client1);
		}
		else
		{
			PCubeFix[client1][PCubes[client1]] = PCube[client1][cube];
			PCube[client1][cube] = -1;
			PCubes[client1] += 1;

			ShowMenu_GamePoker(client1, true);
		}

		if (PCubes[client1] == 5)
		{
			PrintHintText(client1, "%s", Cmb[GetClientCmb(PCubeFix[client1])]);

			if (PCubes[client2] == 5)
			{
				int winner = GetPokerWinner(client1, client2);

				if (winner == 0)
				{
					PrintToChat(client1, "%s Draw. We play again.", GPREFIX);
					PrintToChat(client2, "%s Draw. We play again.", GPREFIX);

					StartGame_Poker(client1);
				}
				else
				{
					char buffer1[256];
					char buffer2[256];

					FormatEx(buffer1, sizeof(buffer1), "[%i] [%i] [%i] [%i] [%i] - (%s) %N", PCubeFix[client1][0], PCubeFix[client1][1], PCubeFix[client1][2], PCubeFix[client1][3], PCubeFix[client1][4], Cmb[GetClientCmb(PCubeFix[client1])], client1);
					FormatEx(buffer2, sizeof(buffer2), "[%i] [%i] [%i] [%i] [%i] - (%s) %N", PCubeFix[client2][0], PCubeFix[client2][1], PCubeFix[client2][2], PCubeFix[client2][3], PCubeFix[client2][4], Cmb[GetClientCmb(PCubeFix[client2])], client2);

					ResultGame(winner, GameName[1], buffer2, buffer1, true);
					ResultGame(GetClientEnemy(winner), GameName[1], buffer2, buffer1);
				}
			}
			else PrintToChat(client1, "%s Player \x04%N\x01 has not put together a combination yet.", GPREFIX, client2);
		}
	}
	else if (action == MenuAction_Cancel)
	{
		if (IsClientPlay(client1))
		{
			ResetGame(client1, client2);
			if (IsValidClient(client2))
			{
				PrintToChat(client1, "%s You didn't have time to collect the combination. Game over.", GPREFIX);
			}
			if (IsValidClient(client2))
			{
				PrintToChat(client2, "%s Player \x04%N\x01 did not have time to collect the combination. Game over.", GPREFIX, client1);
			}
		}
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

int GetPokerWinner(int client1, int client2)
{
	int cmb1 = GetClientCmb(PCubeFix[client1]);
	int cmb2 = GetClientCmb(PCubeFix[client2]);

	if (cmb1 > cmb2)
	{
		return client1;
	}
	else if (cmb1 < cmb2)
	{
		return client2;
	}
	else
	{
		return 0;
	}
}

public Action HudGame_Poker(Handle timer, any client)
{
	if (!IsValidClient(client) || PCubes[client] == 5)
	{
		return Plugin_Stop;
	}

	int t = Time[client], c0 = PCubeFix[client][0], c1 = PCubeFix[client][1], c2 = PCubeFix[client][2], c3 = PCubeFix[client][3], c4 = PCubeFix[client][4];

	char buffer[512];
	switch (PCubes[client])
	{
		case 0: FormatEx(buffer, sizeof(buffer), "%i\n[ ]  [ ]  [ ]  [ ]  [ ]",		t);
		case 1: FormatEx(buffer, sizeof(buffer), "%i\n[%i]  [ ]  [ ]  [ ]  [ ]",		t, c0);
		case 2: FormatEx(buffer, sizeof(buffer), "%i\n[%i]  [%i]  [ ]  [ ]  [ ]",	t, c0, c1);
		case 3: FormatEx(buffer, sizeof(buffer), "%i\n[%i]  [%i]  [%i]  [ ]  [ ]",	t, c0, c1, c2);
		case 4: FormatEx(buffer, sizeof(buffer), "%i\n[%i]  [%i]  [%i]  [%i]  [ ]",	t, c0, c1, c2, c3);
		case 5: FormatEx(buffer, sizeof(buffer), "%i\n[%i]  [%i]  [%i]  [%i]  [%i]",	t, c0, c1, c2, c3, c4);
	}

	if (Time[client] > 0)
	{
		PrintHintText(client, "%s", buffer);
	}
	Time[client] -= 1;

	return Plugin_Continue;
}

int GetClientCmb(int cube[5])
{
	int cmb, count[7];

	for (int i = 0; i < 5; i++)
	{
		switch (cube[i])
		{
			case 1: count[1] += 1;
			case 2: count[2] += 1;
			case 3: count[3] += 1;
			case 4: count[4] += 1;
			case 5: count[5] += 1;
			case 6: count[6] += 1;
		}
	}

	for (int i = 1; i <= 6; i++)
	{
		switch (count[i])
		{
			case 5: cmb = POKER;
			case 4: cmb = QUAD;
			case 3: cmb = SET;
		}
	}

	if (cmb == SET)
	{
		for (int i = 1; i <= 6; i++)
		{
			if (count[i] == 2)
			{
				cmb = FULLHOUSE;
				break;
			}
		}
	}

	if (cmb == NULL)
	{
		bool num[7];
		for (int i = 1; i <= 6; i++)
		{
			for(int d = 1; d <= 6; d++)
			{
				if (count[i] == d)
				{
					num[i] = true;
				}
			}
		}

		if (num[1] && num[2] && num[3] && num[4] && num[5])
		{
			cmb = STRAIGHT;
		}
		else if (num[2] && num[3] && num[4] && num[5] && num[6])
		{
			cmb = STRAIGHT;
		}
	}

	return cmb;
}
