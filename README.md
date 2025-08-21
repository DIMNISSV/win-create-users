# win-create-users
### Как сохранить и запустить скрипт

1.  **Сохраните код:** Скопируйте код и сохраните его в файл с именем `Create-Users.ps1` (например, в `C:\temp\Create-Users.ps1`).
Или скачайте: `curl https://raw.githubusercontent.com/DIMNISSV/win-create-users/refs/heads/master/Create-Users.ps1 -o Create-Users.ps1`
3.  **Подготовьте файл с данными:** Убедитесь, что ваш файл `users.txt` готов и находится в известном вам месте (например, `C:\data\users.txt`).
4.  **Запустите PowerShell от имени Администратора:** Это необходимо для создания пользователей.
5.  **Перейдите в папку со скриптом (необязательно, но удобно):**
    ```powershell
    cd C:\temp
    ```
6.  **Запустите скрипт, указав путь к файлу с данными через аргумент `-PathToFile`:**

    ```powershell
    .\Create-Users.ps1 -PathToFile "C:\data\users.txt"
    ```
    Или, если вы не переходили в папку со скриптом:
    ```powershell
    & "C:\temp\Create-Users.ps1" -PathToFile "C:\data\users.txt"
    ```

Теперь, если вам понадобится создать пользователей из другого файла, вы просто укажете новый путь в команде запуска, не трогая сам скрипт.
