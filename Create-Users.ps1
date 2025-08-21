<#
.SYNOPSIS
    Создает локальных пользователей Windows из текстового файла и добавляет их в указанные группы.

.DESCRIPTION
    Скрипт читает текстовый файл (формат: имя<ТАБ>пароль).
    Для каждой строки он создает локального пользователя, устанавливает требование смены пароля при первом входе
    и опционально добавляет его в одну или несколько локальных групп.

.PARAMETER PathToFile
    Полный путь к текстовому файлу с пользователями.

.PARAMETER Groups
    (Необязательный параметр) Список имен групп через запятую, в которые нужно добавить пользователей.
    Если группа не существует, будет выведено предупреждение.

.EXAMPLE
    # Пример 1: Создать пользователей без добавления в группы
    .\Create-Users.ps1 -PathToFile "C:\data\new_users.txt"

.EXAMPLE
    # Пример 2: Создать пользователей и добавить их в одну группу
    .\Create-Users.ps1 -PathToFile "C:\data\new_users.txt" -Groups "Remote Desktop Users"

.EXAMPLE
    # Пример 3: Создать пользователей и добавить их в несколько групп
    .\Create-Users.ps1 -PathToFile "C:\data\new_users.txt" -Groups "Remote Desktop Users", "Backup Operators"
#>
param(
    [Parameter(Mandatory=$true, HelpMessage="Укажите полный путь к текстовому файлу с пользователями.")]
    [string]$PathToFile,

    [Parameter(Mandatory=$false, HelpMessage="Укажите через запятую группы, в которые нужно добавить пользователей.")]
    [string[]]$Groups = @() # По умолчанию - пустой список
)

# ===================================================================
#               Основная логика скрипта
# ===================================================================

# 1. Проверка, существует ли файл
if (-not (Test-Path $PathToFile)) {
    Write-Host "Ошибка: Файл не найден по пути: '$PathToFile'" -ForegroundColor Red
    exit
}

Write-Host "Начинаю обработку файла: $PathToFile" -ForegroundColor Cyan
if ($Groups.Count -gt 0) {
    Write-Host "Новые пользователи будут добавлены в следующие группы: $($Groups -join ', ')" -ForegroundColor Cyan
}

# 2. Чтение файла и создание пользователей
$users = Import-Csv -Path $PathToFile -Delimiter "`t" -Header "UserName", "Password"

foreach ($user in $users) {
    if ([string]::IsNullOrWhiteSpace($user.UserName)) {
        continue
    }

    $username = $user.UserName.Trim()
    $password = $user.Password

    if (Get-LocalUser -Name $username -ErrorAction SilentlyContinue) {
        Write-Host "Пользователь '$username' уже существует. Пропускаем." -ForegroundColor Yellow
        continue
    }

    try {
        # Шаг 1: Создание пользователя
        $securePassword = ConvertTo-SecureString -String $password -AsPlainText -Force
        New-LocalUser -Name $username -Password $securePassword -FullName $username -Description "Создан скриптом $(Get-Date)"

        Write-Host "УСПЕХ: Пользователь '$username' успешно создан." -ForegroundColor Green

        # Шаг 2: Установка требования смены пароля через ADSI
        $adsiUser = [ADSI]"WinNT://localhost/$username,user"
        $adsiUser.psbase.InvokeSet("PasswordExpired", 1)
        $adsiUser.CommitChanges()
        Write-Host "  -> Установлено требование смены пароля при следующем входе." -ForegroundColor Green
        
        # Шаг 3: Добавление в группы, если они были указаны
        if ($Groups.Count -gt 0) {
            foreach ($groupName in $Groups) {
                # Проверяем, существует ли группа, перед добавлением
                if (Get-LocalGroup -Name $groupName -ErrorAction SilentlyContinue) {
                    Add-LocalGroupMember -Group $groupName -Member $username
                    Write-Host "  -> Успешно добавлен в группу '$groupName'." -ForegroundColor Green
                } else {
                    Write-Host "  -> ПРЕДУПРЕЖДЕНИЕ: Группа '$groupName' не найдена. Пропускаем." -ForegroundColor Yellow
                }
            }
        }
    }
    catch {
        Write-Host "ОШИБКА при обработке пользователя '$username':" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
    Write-Host "" # Добавляем пустую строку для лучшей читаемости вывода
}

Write-Host "`nОбработка завершена." -ForegroundColor Cyan
