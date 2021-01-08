int Object[MAXPLAYERS+1];

char ObjectName[][] =
{
	"Rock",
	"Scissors",
	"Paper"
};

void StartGame_KNB(int client1)
{
	int client2 = GetClientEnemy(client1);
	if (!IsClientPlay(client2))
	{
		return;
	}

	ShowMenu_GameKNB(client1);
	ShowMenu_GameKNB(client2);

	if (!IsValidClient(client1) || !IsValidClient(client2))
	{
		ResetGame(client1, client2);
	}
}

void ShowMenu_GameKNB(int client)
{
	CreateTimer(1.0, HudGame_KNB, client, TIMER_REPEAT);

	PrintToChat(client, "%s The game has begun.", GPREFIX);
	Object[client] = -1;
	Time[client] = GameTime;

	Menu menu = new Menu(GameKNB_MenuHandler);
	menu.SetTitle("%s:\n \n", GameName[0]);

	menu.AddItem("", "Rock");
	menu.AddItem("", "Scissors");
	menu.AddItem("", "Paper");

	menu.ExitButton = false;
	menu.Display(client, GameTime);
}

public int GameKNB_MenuHandler(Menu menu, MenuAction action, int client1, int param)
{
	int client2;
	if (client1 > 0)
	{
		client2 = GetClientEnemy(client1);
	}

	if (action == MenuAction_End)
	{
		delete menu;
	}
	else if (action == MenuAction_Cancel)
	{
		if (IsClientPlay(client1))
		{
			ResetGame(client1, client2);

			if (IsValidClient(client1))
			{
				PrintToChat(client1, "%s You didn't have time to decide. Game over.", GPREFIX);
			}

			if (IsValidClient(client2))
			{
				PrintToChat(client2, "%s Player \x04%N\x01 did not have time to decide. Game over.", GPREFIX, client1);
			}
		}
	}
	else if (action == MenuAction_Select)
	{
		Object[client1] = param;
		Time[client1] = 0;
		PrintHintText(client1, "%s", ObjectName[param]);

		if (Object[client1] >= 0 && Object[client2] >= 0)
		{
			int winner = GetKNBWinner(client1, client2);

			if (winner == 0)
			{
				PrintToChat(client1, "%s Ничья. Играем еще раз.", GPREFIX);
				PrintToChat(client2, "%s Ничья. Играем еще раз.", GPREFIX);

				StartGame_KNB(client1);
			}
			else
			{
				char buffer1[128], buffer2[128];
				FormatEx(buffer1, sizeof(buffer1), "[%s] %N", ObjectName[Object[client1]], client1);
				FormatEx(buffer2, sizeof(buffer2), "[%s] %N", ObjectName[Object[client2]], client2);

				ResultGame(winner, GameName[0], buffer2, buffer1, true);
				ResultGame(GetClientEnemy(winner), GameName[0], buffer2, buffer1);
			}
		}
		else
		{
			PrintToChat(client1, "%s Player \x04%N\x01 has not decided yet.", GPREFIX, client2);
		}
	}
}

public Action HudGame_KNB(Handle timer, any client)
{
	if (!IsValidClient(client) || Time[client] <= 0)
	{
		return Plugin_Stop;
	}

	PrintHintText(client, "%i", Time[client]);
	Time[client] -= 1;

	return Plugin_Continue;
}

int GetKNBWinner(int client1, int client2)
{
	int c1 = Object[client1], c2 = Object[client2];
	if (c1 == 0 && c2 == 2 || c1 == 1 && c2 == 0 || c1 == 2 && c2 == 1)
	{
		return client2;
	}
	else if (c1 == 0 && c2 == 1 || c1 == 1 && c1 == 2 || c1 == 2 && c2 == 0)
	{
		return client1;
	}
	return 0;
}

