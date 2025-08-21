# win-create-users

Сохраните код в файл, например `Create-Users.ps1`.

`curl https://raw.githubusercontent.com/DIMNISSV/win-create-users/refs/heads/master/Create-Users.ps1 -o Create-Users.ps1`


**Сценарий 1: Просто создать пользователей**

```powershell
.\Create-Users.ps1 -PathToFile "C:\data\users.txt"
```

**Сценарий 2: Создать пользователей и добавить их всех в группу "Пользователи удаленного рабочего стола"**

```powershell
.\Create-Users.ps1 -PathToFile "C:\data\users.txt" -Groups "Remote Desktop Users"
```
*(Имя группы можно писать как на английском, так и на русском, если система русскоязычная: "Пользователи удаленного рабочего стола")*

**Сценарий 3: Создать пользователей и добавить их в группы "Пользователи удаленного рабочего стола" и "Операторы архива"**

```powershell
.\Create-Users.ps1 -PathToFile "C:\data\users.txt" -Groups "Remote Desktop Users", "Backup Operators"
```
