 /* *******************************************************		************************************************************** 
 *	Checks if the audio file is MP3 							*	Проверяет, является ли аудиофайл в формате .MP3 
 *																*	
 *	@param1	- The path to the sound file. Path must 			*	@param1	- Путь к звуковому файлу. Путь должен начинаться 
 *	start after "sound/...".									*	после "sound/...".	
 *																*
 *	@return - none.												*	@return - ничего не возвращает.	
 *																*
 * ******************************************************** 	************************************************************ */	
stock bool IsAudioFileMP3(char[] path, const int maxlength, char[] name, char[] key)
{
	ReplaceString(path, maxlength, " ", "", false);
	
	if(strlen(name) == 0)
	{
		LogError("You specified an empty sound file name! (Key %s, qualifier 'name') * Вы указали пустое имя звукового файла! (Ключ %s, спецификатор 'name') *", key, key);
		return false;
	}
	
	if(strlen(path) == 0)
	{
		LogError("You specified an empty path to the sound file! (Key %s, qualifier 'path') * Вы указали пустой путь к звуковому файлу! (Ключ %s, спецификатор 'path') *", key, key);
		return false;
	}

	if(StrContains(path, ".mp3", true) == -1)
	{
		LogError("The file does not conform to the .mp3 audio format! (%s) * Файл не соответствует аудио формату .mp3! (%s) *", path, path);
		return false;
	}
	
	return true;
}


 /* **************************************************************	*********************************************************************** 
 *	Shows all music kits of a specific player.						*	Показывает все музыкальные наборы определенного игрока
 *																	*	
 *	@param1	- Client index. 										*	@param1	- Индекс клиента.
 *	@param2	- Object menu.											*	@param2	- Объект menu.
 *																	*
 *	@return - true if the player has music kits, false otherwise.	*	@return - истина, если у игрока есть музыкальные наборы, иначе ложь
 *																	*
 * ***************************************************************	********************************************************************* */	
stock void ShowPlayerMusicKits(int client, Menu menu)
{
	KeyValues hKeyValue = new KeyValues("Players");
	hKeyValue.Rewind(); // Players
	
	int key = 0; // количество ключей (наборов)
	
	if(hKeyValue.ImportFromFile(g_szPathPlayersKeyValues))
	{
		char SteamID64[18], SteamId[20], IP[16];
		GetClientAuthId(client, AuthId_SteamID64, SteamID64, sizeof(SteamID64));
		GetClientAuthId(client, AuthId_Steam2, SteamId, sizeof(SteamId));
		GetClientIP(client, IP, sizeof(IP), false);
		
		if(hKeyValue.GotoFirstSubKey()) // SteamId / IP игроков
		{
			do
			{
				char Section[64];
				hKeyValue.GetSectionName(Section, sizeof(Section));
				
				if(StrContains(Section, SteamID64) != -1 || StrContains(Section, SteamId) != -1 || StrContains(Section, IP) != -1) // если игрок есть в списке players.cfg
				{
					if(hKeyValue.GotoFirstSubKey()) // Музыкальные наборы игрока
					{
						do
						{
							char sKitName[PLATFORM_MAX_PATH];
							key++; // номера ключей (наборов) начинаются СТРОГО с 1 и каждый новый увеличивается на +1
							hKeyValue.GetSectionName(sKitName, sizeof(sKitName));
							menu.AddItem(sKitName, sKitName);
						}
						while(hKeyValue.GotoNextKey()); 
					}
				}
			}
			while(hKeyValue.GotoNextKey()); 
		}
	}
	
	delete hKeyValue;
	g_iKits[client] = key; // число наборов у игрока
	
	if(key > 0)
	{
		return;
	}
}

/* ***************************************************************  ************************************************************************** 
 *	Shows all music kits of a specific player.						*	Показывает все композиции в музыкальном наборе определенного игрока
 *																	*	
 *	@param1	- Client index. 										*	@param1	- Индекс клиента.
 *	@param2	- Name musical kit. 									*	@param2	- Навзание музыкального набора.
 *	@param3	- Object menu.											*	@param3	- Объект menu.
 *																	*
 *	@return - true if the player has compositions in musical kit, 	*	@return - истина, если у игрока есть композиции в музыкальном наборе, 
 *	false otherwise.												*	иначе ложь.
 *																	*
 * **************************************************************	*********************************************************************** */
stock void ShowPlayerMusic(int client, const char[] kit, Menu menu)
{
	KeyValues hKeyValue = new KeyValues("Players");
	hKeyValue.Rewind(); // Players
	
	int key = 0; // количество ключей (композиций)
	
	if(hKeyValue.ImportFromFile(g_szPathPlayersKeyValues))
	{
		char SteamID64[18], SteamId[20], IP[16];
		GetClientAuthId(client, AuthId_SteamID64, SteamID64, sizeof(SteamID64));
		GetClientAuthId(client, AuthId_Steam2, SteamId, sizeof(SteamId));
		GetClientIP(client, IP, sizeof(IP), false);
	
		if(hKeyValue.GotoFirstSubKey()) // SteamId / IP игроков
		{
			do
			{
				char Section[64];
				hKeyValue.GetSectionName(Section, sizeof(Section));
				
				if(StrContains(Section, SteamID64) != -1 || StrContains(Section, SteamId) != -1 || StrContains(Section, IP) != -1) // если игрок есть в списке players.cfg
				{
					if(hKeyValue.JumpToKey(kit))
					{
						if(hKeyValue.GotoFirstSubKey(false)) // Считаем число композиций
						{
							do
							{
								key++; // номера ключей (композиций) начинаются СТРОГО с 1 и каждый новый увеличивается на +1
							}
							while(hKeyValue.GotoNextKey(false));
							hKeyValue.GoBack(); // выходим из сабключей (композиций)
						}
						else
						{
							if(gc_bPluginMessage.BoolValue) CPrintToChat(client, "%s %t", g_sPrefix, "Chat_Musical_Kit_Empty");
						}
						
						if(key > 0) // если у игрока есть композиции
						{
							for(int i = 1; i <= key; ++i)
							{
								char path[PLATFORM_MAX_PATH], name[PLATFORM_MAX_PATH], sNumber[10];
								IntToString(i, sNumber, sizeof(sNumber));
								hKeyValue.GetString(sNumber, path, sizeof(path));
								hKeyValue.GetString(sNumber, path, sizeof(path));
								if(!GetTrieString(g_hMusicTrie, path, name, sizeof(name)))
								{
									char player[MAX_NAME_LENGTH]; GetClientName(client, player, sizeof(player));
									LogError("%T", "KeyValue_Wrong_Composition_Path", LANG_SERVER, player, path);
								}
								else
								{
									menu.AddItem(path, name);
								}
							}
						}
					}
				}
			}
			while(hKeyValue.GotoNextKey()); 
		}
	}
	
	delete hKeyValue;
	g_iCompositions[client] = key; // число композиций у игрока
	
	if(key > 0)
	{
		return;
	}
}

/* ******************************************************************* 	************************************************************************** 
 *	Displays all information about the composition in a separate menu.	*	Выводит в отдельное окно всю информацию о композиции.
 *																		*	
 *	@param1	- Client index. 											*	@param1	- Индекс клиента.
 *	@param2	- The path to the sound file. Path must 					*	@param2	- Путь к звуковому файлу. Путь должен начинаться 
 *	start after "sound/...".											*	после "sound/...".																	*
 *																		*																
 *	@return - true if the player has the composition and the 	 		*	@return - истина, если композиция присутсвует у игрока, и информация 
 *	information was successfully displayed in a separate menu, 			*	успешно было выведена в отдельное окно, иначе ложь.
 *	otherwise false.													*
 *																		*
 * *******************************************************************	*********************************************************************** */
 stock bool ShowComposition(int client, const char[] path)
{
	KeyValues hKeyValue = new KeyValues("Settings");
	hKeyValue.Rewind(); // Settings
	
	if(hKeyValue.ImportFromFile(g_szPathSettingsKeyValues))
	{
		if(hKeyValue.GotoFirstSubKey()) // Путь к композиции
		{
			do
			{
				char Section[PLATFORM_MAX_PATH];
				hKeyValue.GetSectionName(Section, sizeof(Section));
				
				if(StrEqual(path, Section))
				{
					char name[PLATFORM_MAX_PATH], duration[16], cost[16], description[64];
					hKeyValue.GetString("name", name, sizeof(name));
					hKeyValue.GetString("duration", duration, sizeof(duration));
					hKeyValue.GetString("cost", cost, sizeof(cost));
					hKeyValue.GetString("description", description, sizeof(description));
					Panel_ShowComposition(client, name, duration, cost, description, path);
					
					delete hKeyValue;
					return true;
				}
			}
			while(hKeyValue.GotoNextKey());
		}
	}

	delete hKeyValue;
	return false;
}

/* **************************************************************	*********************************************************************** 
*	Creates a shop menu	with categories.							*	Создает меню магазина с категориями.
*																	*	
*	@param1	- Client index. 										*	@param1	- Индекс клиента.
*	@param2	- Object menu.											*	@param2	- Объект menu.
*																	*
*	@return - None.													*	@return - Ничего не возвращает.
*																	*
* ***************************************************************	********************************************************************* */
 stock void CreateShopCategory(int client, Menu menu)
 {
	KeyValues hKeyValue = new KeyValues("Shop");
	hKeyValue.Rewind(); // Shop
	
	if(hKeyValue.ImportFromFile(g_szPathShopKeyValues))
	{
		if(hKeyValue.GotoFirstSubKey()) 
		{
			do
			{
				char Section[PLATFORM_MAX_PATH];
				hKeyValue.GetSectionName(Section, sizeof(Section));
				menu.AddItem(Section, Section);
			}
			while(hKeyValue.GotoNextKey());
		}
	}

	delete hKeyValue;
 }
 
/* **************************************************************	*********************************************************************** 
 *	Creates a shop menu	with music kits which are in a 				*	Создает меню магазина с композициями, которые находятся в 
 *	specific kit.													*	определенном музыкальном наборе.
 *																	*	
 *	@param1	- Client index. 										*	@param1	- Индекс клиента.
 *	@param2	- Object menu.											*	@param2	- Объект menu.
 *	@param3	- Name musical kit. 									*	@param3	- Навзание музыкального набора.
 *																	*
 *	@return - none.													*	@return - ничего не возвращает.
 *																	*
 * ***************************************************************	********************************************************************* */
 stock void CreateShopCompositions(int client, Menu menu, const char[] kit)
 {
	KeyValues kv = new KeyValues("Settings");
	kv.Rewind(); // Settings
	
	g_iShopBuffer[client] = 0;
	int key = 0;
	
	if(kv.ImportFromFile(g_szPathSettingsKeyValues))
	{
		if(kv.GotoFirstSubKey()) 
		{
			do
			{
				char path[PLATFORM_MAX_PATH], name[PLATFORM_MAX_PATH], music_kits[MAX_NAME_LENGTH];
				kv.GetSectionName(path, sizeof(path));
				GetMusicMethod(path, "category", music_kits, sizeof(music_kits));
				GetTrieString(g_hMusicTrie, path, name, sizeof(name));
				if(StrContains(music_kits, kit, false) != -1)
				{
					key++;
					menu.AddItem(path, name);
				}
			}
			while(kv.GotoNextKey());
		}
	}

	delete kv;
	g_iShopBuffer[client] = key;
 }
 
 /* ********************************************************	******************************************************************************** 
 *	Gets a specific method from a music track specifier. 		*	Извлекает определенный метод из спецификатора музыкальной 
 *																*	дорожки. 
 *	The KV "Settings" structure has sound files, 				*	
 *	each sound file has a method that stores certain 			*	КВ структура Settings имеет звуковые файлы, каждый звуковой файл имеет
 *	information about the audio file.							*	метод (флаг), который хранить определенную информацию о аудифайле.
 *																*	
 *	@param1	- The path to the sound file. Path must 			*	@param1	- Путь к звуковому файлу. Путь должен начинаться 
 *	start after "sound/...".									*	после "sound/...".
 *	@param2	- The method to retrieve. 							*	@param2	- Метод, который нужно извлечь.
 *	@param3	- A string buffer for storage.  					*	@param3	- Строковой буффер для хранения.															
 *	@param4	- The maximum size of the buffer. 					*	@param4	- Максимальный размер буффера.																
 *	@return - true if the method was successfully retrieved, 	*	@return - истина, если метод был успешно извлечен, иначе ложь.															
 *	false otherwise. 											*	
 *																*
 * ******************************************************** 	******************************************************************************* */	
stock bool GetMusicMethod(const char[] path, const char[] method, char[] buffer, const int maxlength)
{
	KeyValues hKeyValue = new KeyValues("Settings");
	hKeyValue.Rewind();
	
	if(hKeyValue.ImportFromFile(g_szPathSettingsKeyValues))
	{
		if(hKeyValue.GotoFirstSubKey()) // Путь к композиции
		{
			do
			{
				char Section[PLATFORM_MAX_PATH];
				hKeyValue.GetSectionName(Section, sizeof(Section));
				
				if(StrEqual(path, Section))
				{
					hKeyValue.GetString(method, buffer, maxlength, "-1");
					
					if(StrEqual("-1", buffer))
					{
						LogError("%T", "KeyValue_Nonexistent_Method", LANG_SERVER, method);
						delete hKeyValue;
						return false;
					}
					
					delete hKeyValue;
					return true;
				}
			}
			while(hKeyValue.GotoNextKey());
		}
	}

	delete hKeyValue;
	return false;	
}

/* **************************************************************	*********************************************************************** 
 *	Returns the number of client tracks			 					*	Возвращает число композиций клиента.
 *																	*	
 *	@param1	- Client index. 										*	@param1	- Индекс клиента.
 *	@return - Number of tracks.										*	@return - Число композиций.
 *																	*
 * ***************************************************************	********************************************************************* */
stock int TrackCounter(int client)
{
	KeyValues kv = new KeyValues("Players");
	kv.Rewind(); // Players
	
	int tracks = 0;
	
	if(kv.ImportFromFile(g_szPathPlayersKeyValues))
	{
		char SteamID64[18], SteamId[20], IP[16];
		GetClientAuthId(client, AuthId_SteamID64, SteamID64, sizeof(SteamID64));
		GetClientAuthId(client, AuthId_Steam2, SteamId, sizeof(SteamId));
		GetClientIP(client, IP, sizeof(IP), false);
	
		if(kv.GotoFirstSubKey())
		{
			do
			{
				char Section[20];
				kv.GetSectionName(Section, sizeof(Section));
					
				if(StrContains(Section, SteamID64) != -1 || StrContains(Section, SteamId) != -1 || StrContains(Section, IP) != -1) 
				{
					if(kv.GotoFirstSubKey()) 
					{
						do
						{
							if(kv.GotoFirstSubKey(false))
							{
								do
								{
									tracks++;
								}
								while(kv.GotoNextKey(false));
								kv.GoBack();
							}
						}
						while(kv.GotoNextKey()); 
					}
				}
			}
			while(kv.GotoNextKey()); 
		}
	}
	
	delete kv;
	return tracks;
}

/* **************************************************************	*********************************************************************** 
 *	Returns the number of client tracks			 					*	Сохраняет все звуки на карте (в начале раунда).
 *																	*	
 *	@return - None.													*	@return - Ничего не возвращает.
 *																	*
 * ***************************************************************	********************************************************************* */
stock void SaveSoundsOnMap()
{
	char name[PLATFORM_MAX_PATH]; // название звукового файла (путь)
	int entity = INVALID_ENT_REFERENCE;
	
	g_iSounds = 0; 

	while((entity = FindEntityByClassname(entity, "ambient_generic")) != INVALID_ENT_REFERENCE)
	{
		GetEntPropString(entity, Prop_Data, "m_iszSound", name, sizeof(name));
		int size = strlen(name);
		
		if (size >= 5 && (StrEqual(name[size-4], ".mp3") || StrEqual(name[size-4], ".wav"))) // размер названия файла не может быть меньше 5 символов, нас интересует только формат звукового фалй => Size - 3
		{
			g_iEntitySound[g_iSounds++] = EntIndexToEntRef(entity);
		}
	}
}

/* **************************************************************	*********************************************************************** 
 *	Returns the number of client tracks			 					*	Сохраняет все звуки на карте (в начале раунда).
 *																	*	
 *	@return - None.													*	@return - Ничего не возвращает.
 *																	*
 * ***************************************************************	********************************************************************* */
 stock void OffOtherSounds()
 {
	char sSound[PLATFORM_MAX_PATH];
	int entity = INVALID_ENT_REFERENCE;
	
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(IsValidClient(i) && !IsBotClient(i))
		{
			for(int j = 0; j < g_iSounds; ++j)
			{
				entity = EntRefToEntIndex(g_iEntitySound[j]);
					
				if(IsValidEntity(entity))
				{
					GetEntPropString(entity, Prop_Data, "m_iszSound", sSound, sizeof(sSound));
					EmitSoundToClient(i, sSound, entity, SNDCHAN_STATIC, SNDLEVEL_NONE, SND_STOP, 0.0, SNDPITCH_NORMAL, 0, NULL_VECTOR, NULL_VECTOR, true);
				}
			}
		}
	}
 }

/* **************************************************************	*********************************************************************** 
 *	Sets music in the audio player.									*	Устанавливает музыку в аудиоплеер.
 *																	*	
 *	@param1	- Client index. 										*	@param1	- Индекс клиента.
 *	@return - True, if the track was sets, otherwise false.			*	@return - Истина, если удалось установить композицию, иначе ложь.
 *																	*
 * ***************************************************************	********************************************************************* */
stock bool SetMusicMVP(int client)
{
	int tracks = TrackCounter(client);
	
	if(tracks == 0) // если у игрока нет, композиций
	{
		return false;
	}
	
	tracks  = GetRandomInt(1, tracks); // присваиваем новое значение, для выбора рандомной пластинки
	
	KeyValues kv = new KeyValues("Players");
	kv.Rewind(); // Players
	
	if(kv.ImportFromFile(g_szPathPlayersKeyValues))
	{
		char SteamID64[18], SteamId[20], IP[16];
		GetClientAuthId(client, AuthId_SteamID64, SteamID64, sizeof(SteamID64));
		GetClientAuthId(client, AuthId_Steam2, SteamId, sizeof(SteamId));
		GetClientIP(client, IP, sizeof(IP), false);
	
		if(kv.GotoFirstSubKey())
		{
			do
			{
				char Section[64];
				kv.GetSectionName(Section, sizeof(Section));
					
				if(StrContains(Section, SteamID64) != -1 || StrContains(Section, SteamId) != -1 || StrContains(Section, IP) != -1) 
				{
					if(kv.GotoFirstSubKey()) 
					{
						do
						{
							if(kv.GotoFirstSubKey(false))
							{
								do
								{
									tracks--;
									if(tracks == 0)
									{
										char buffer[PLATFORM_MAX_PATH];
										kv.GetSectionName(Section, sizeof(Section));
										kv.GoBack();
										kv.GetString(Section, buffer, sizeof(buffer));
										FormatEx(g_sAudioPlayer, sizeof(g_sAudioPlayer), "%s", buffer);
										delete kv;
										return true;
									}
								}
								while(kv.GotoNextKey(false));
								kv.GoBack();
							}
						}
						while(kv.GotoNextKey()); 
					}
				}
			}
			while(kv.GotoNextKey()); 
		}
	}
	
	delete kv;
	return false;
}

/* **************************************************************	*********************************************************************** 
 *	Plays the client's track.										*	Воспроизводит композицию клиента.
 *																	*	
 *	@param1	- Client index. 										*	@param1	- Индекс клиента.
 *	@return - None.													*	@return - Ничего не возвращает.
 *																	*
 * ***************************************************************	********************************************************************* */
stock void PlayMusic(int client)
{
	g_iMVPBuffer = client; // сохраняем последнего MVP

	for(int i = 1; i <= MaxClients; ++i)
	{
		if(IsValidClient(i) && !IsBotClient(i) && g_bMVPMusic[i] && !g_bDisableMVPMusic[i][client]) // g_bMVPMusic - если игрок разрешает воспроизводить музыку MVP
		{
			if(strlen(g_sAudioPlayer) > 1) 
				StopSound(i, SNDCHAN_AUTO, g_sAudioPlayer);
		
			if(strlen(g_sCheckVolume) > 1) 
				StopSound(i, SNDCHAN_AUTO, g_sCheckVolume);
		
			if(strlen(g_sPlaylist[i]) > 1)
				StopSound(i, SNDCHAN_AUTO , g_sPlaylist[i]);
			
			if(gc_bPluginMessage.BoolValue)	
			{
				char name[MAX_NAME_LENGTH]; GetMusicMethod(g_sAudioPlayer, "name", name, sizeof(name));
				if(strlen(name) != 0)
				{
					if(gc_bPluginMessage.BoolValue) CPrintToChat(i, "%s %t", g_sPrefix, "Chat_Player_MVP", client, name);		
				}
			}
			
			EmitSoundToClient(i, g_sAudioPlayer, -2, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, g_flVolume[client]);
		}
	}
}

/* **************************************************************	*********************************************************************** 
 *	Sets default options.											*	Скидывает все парметры клиента по умолчанию.
 *																	*	
 *	@param1	- Client index to search.								*	@param1 - Индекс клиента для поиска.
 *	@return - True if parameters were discarded, false otherwise.	*	@return - Истина, если параметры были скинуты, иначе ложь.
 *																	*
 * ***************************************************************	********************************************************************* */
 stock void SetsDefaultClientOptions(int client)
 {
	g_bMVPMusic[client] = true;	// воспроизведение музыки для всех клиентов (0 - выкл, 1 - вкл)
	g_iVolume[client] = 100; // устанавливаем дефолтную громкость звука в процентах 
	g_flVolume[client] = 1.0; // устанавливаем дефолтный множитель громкость звука  
	
	for(int i = 1; i <= MaxClients; ++i)
	{
		g_bDisableMVPMusic[i][client] = false; // воспроизведение у конкретного i игрока, т.к. данный индекс займет новый игрок
	}
	
	
 }

/* ************************************************************************	*********************************************************************** 
 *	Creates a KeyValues ​​structure and checks for specific 					*	Создает KeyValues структуру и проверяет на наличие определенных 
 *	problems.																*	проблем.
 *																			*	
 *	@param1	- Object KeyValues.												*	@param1	- Объект KeyValues.
 *	@param2	- Path to the file 'music.cfg'. 								*	@param2	- Путь к файлу 'music.cfg'.
 *	@return - true if the structure exists and a path to it has been 		*	@return - истина если структура существует и путь к ней был создан, 
 *	created, false otherwise.												*	иначе ложь.	
 *																			*
 * ************************************************************************	********************************************************************* */
stock bool InitKeyValueMusicStruct(KeyValues &kv, const char[] path)
{
	kv.Rewind(); 
	g_hMusicTrie = new StringMap(); // в дереве храним пути к файлам и соотвествующие названия аудифайлов
	
	BuildPath(Path_SM, g_szPathMusicKeyValues, sizeof(g_szPathMusicKeyValues), path); 

	if(kv.ImportFromFile(g_szPathMusicKeyValues)) // если файл открывается 
	{
		if(kv.GotoFirstSubKey()) // если в файле есть композиции и они пронумерованы 
		{
			do
			{
				char szPath[PLATFORM_MAX_PATH], szName[PLATFORM_MAX_PATH], section[10]; // szPath - путь к файлу, szName - название файла, section - номер ключа
				kv.GetString("name", szName, sizeof(szName));
				kv.GetString("path", szPath, sizeof(szPath));
				kv.GetSectionName(section, sizeof(section));
				
				if(IsAudioFileMP3(szPath, sizeof(szPath), szName, section))
				{
					PrecacheAndDownloadSoundFile(szPath);
					g_hMusicTrie.SetString(szPath, szName);
				}
			}
			while(kv.GotoNextKey()); // 2, 3, etc.
		}
		else
		{
			LogError("%T", "KeyValue_Missing_First_Audio_Key", LANG_SERVER);
			return false;
		}
	}
	else
	{	
		LogError("%T", "KeyValue_Struct_Not_Created_Music", LANG_SERVER, g_szPathMusicKeyValues);
		return false;
	}
	
	return true;
}

/* ************************************************************************	*********************************************************************** 
 *	Creates a KeyValues ​​structure and checks for specific 					*	Создает KeyValues структуру и проверяет на наличие определенных 
 *	problems.																*	проблем.
 *																			*									
 *	@param1	- Object KeyValues.												*	@param1	- Объект KeyValues.
 *	@param2	- Path to the file 'players.cfg'. 								*	@param2	- Путь к файлу 'players.cfg'.
 *	@return - true if the structure exists and a path to it has been 		*	@return - истина если структура существует и путь к ней был создан, 
 *	created, false otherwise.												*	иначе ложь.	
 *																			*
 * ************************************************************************	********************************************************************* */
stock bool InitKeyValuePlayersStruct(KeyValues &kv, const char[] path)
{
	kv.Rewind(); // Players
	
	BuildPath(Path_SM, g_szPathPlayersKeyValues, sizeof(g_szPathPlayersKeyValues), path);
	
	if(kv.ImportFromFile(g_szPathPlayersKeyValues))
	{
		if(kv.GotoFirstSubKey()) // если есть игрок 
		{
			if(kv.GotoFirstSubKey()) // если у игрока есть альбом(ы)
			{
				if(kv.GotoFirstSubKey(false)) // если у игрока есть треки в альбоме
				{
					return true;
				}
				else
				{
					LogError("%T", "KeyValue_Missing_Compositions_In_Kit", LANG_SERVER, g_szPathPlayersKeyValues);
				} 
			}
			else
			{
				LogError("%T", "KeyValue_Missing_Kits", LANG_SERVER, g_szPathPlayersKeyValues);
			} 
		}
		else
		{
			LogError("%T", "KeyValue_Missing_First_Key", LANG_SERVER, g_szPathPlayersKeyValues);
		}
	}
	else
	{
		LogError("%T", "KeyValue_Struct_Not_Created", LANG_SERVER, g_szPathPlayersKeyValues);
	}
	
	return false;
}

/* ************************************************************************	*********************************************************************** 
 *	Creates a KeyValues ​​structure and checks for specific 					*	Создает KeyValues структуру и проверяет на наличие определенных 
 *	problems.																*	проблем.
 *																			*									
  *	@param1	- Object KeyValues.												*	@param1	- Объект KeyValues.						
 *	@param2	- Path to the file 'settings.cfg'. 								*	@param2	- Путь к файлу 'settings.cfg'.
 *	@return - true if the structure exists and a path to it has been 		*	@return - истина если структура существует и путь к ней был создан, 
 *	created, false otherwise.												*	иначе ложь.	
 *																			*
 * ************************************************************************	********************************************************************* */
stock bool InitKeyValueSettingsStruct(KeyValues &kv, const char[] path)
{
	kv.Rewind(); // Settings
	
	BuildPath(Path_SM, g_szPathSettingsKeyValues, sizeof(g_szPathSettingsKeyValues), path);
	
	if(kv.ImportFromFile(g_szPathSettingsKeyValues))
	{
		if(kv.GotoFirstSubKey()) // если путь был найден 
		{
			char szName[PLATFORM_MAX_PATH], szMusic[PLATFORM_MAX_PATH]; kv.GetSectionName(szMusic, sizeof(szMusic));
			kv.GetString("name", szName, sizeof(szName), "-1");
			if(!StrEqual(szName, "-1"))
			{
				return true;
			}
			else
			{
				LogError("%T", "KeyValue_Missing_Method_Name", LANG_SERVER, szMusic, g_szPathSettingsKeyValues);
			}
		}
		else
		{
			LogError("%T", "KeyValue_Missing_First_Key", LANG_SERVER, g_szPathSettingsKeyValues);
		}
	}
	else
	{
		LogError("%T", "KeyValue_Struct_Not_Created", LANG_SERVER, g_szPathSettingsKeyValues);
	}
	
	return false;
}

/* ************************************************************************	*********************************************************************** 
 *	Creates a KeyValues ​​structure and checks for specific 					*	Создает KeyValues структуру и проверяет на наличие определенных 
 *	problems.																*	проблем.
 *																			*									
 *	@param1	- Object KeyValues.												*	@param1	- Объект KeyValues.						
 *	@param2	- Path to the file 'shop.cfg'. 									*	@param2	- Путь к файлу 'shop.cfg'.
 *	@return - true if the structure exists and a path to it has been 		*	@return - истина если структура существует и путь к ней был создан, 
 *	created, false otherwise.												*	иначе ложь.					
 *																			*
 * ************************************************************************	********************************************************************* */
stock bool InitKeyValueShopStruct(KeyValues &kv, const char[] path)
{
	kv.Rewind(); // Shop
	
	BuildPath(Path_SM, g_szPathShopKeyValues, sizeof(g_szPathShopKeyValues), path);
	
	if(kv.ImportFromFile(g_szPathShopKeyValues))
	{
		if(kv.GotoFirstSubKey()) 
		{
			return true;
		}
		else
		{
			LogError("%T", "KeyValue_Struct_Not_Created", LANG_SERVER, g_szPathShopKeyValues);
		}
	}
	
	return false;
}