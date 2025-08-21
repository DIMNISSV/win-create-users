<#
.SYNOPSIS
    Создает локальных пользователей Windows из текстового файла, добавляет их в группы и управляет требованием смены пароля.

.DESCRIPTION
    Скрипт читает текстовый файл (формат: имя<ТАБ>пароль).
    Для каждой строки он создает пользователя и опционально добавляет его в группы.
    Управляет требованием смены пароля при первом входе через параметр -ForcePasswordChange.

.PARAMETER PathToFile
    Полный путь к текстовому файлу с пользователями.

.PARAMETER Groups
    (Необязательный) Список имен групп через запятую, в которые нужно добавить пользователей.

.PARAMETER ForcePasswordChange
    (Необязательный) Определяет, нужно ли требовать смену пароля.
    $true (по умолчанию) - пользователь должен будет сменить пароль при первом входе.
    $false - пароль устанавливается как постоянный.

.EXAMPLE
    # Пример 1: Создать пользователей и потребовать смену пароля (поведение по умолчанию)
    .\Create-Users.ps1 -PathToFile "C:\data\temps.txt" -Groups "Remote Desktop Users"

.EXAMPLE
    # Пример 2: Создать пользователей с постоянными паролями без требования смены
    .\Create-Users.ps1 -PathToFile "C:\data\admins.txt" -ForcePasswordChange:$false

.EXAMPLE
    # Пример 3: Создать пользователей с постоянными паролями и добавить в несколько групп
    .\Create-Users.ps1 -PathToFile "C:\data\powerusers.txt" -Groups "Remote Desktop Users", "Power Users" -ForcePasswordChange:$false
#>
param(
    [Parameter(Mandatory=$true, HelpMessage="Укажите полный путь к текстовому файлу с пользователями.")]
    [string]$PathToFile,

    [Parameter(Mandatory=$false, HelpMessage="Укажите через запятую группы, в которые нужно добавить пользователей.")]
    [string[]]$Groups = @(),

    [Parameter(Mandatory=$false, HelpMessage="Установить требование смены пароля при первом входе.")]
    [bool]$ForcePasswordChange = $true # По умолчанию - ТРЕБУЕМ смену пароля
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
    Write-Host "Новые пользователи будут добавлены в группы: $($Groups -join ', ')" -ForegroundColor Cyan
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

        # === НОВЫЙ БЛОК: Управление сменой пароля ===
        # Шаг 2: Устанавливаем требование смены пароля, только если параметр $ForcePasswordChange равен $true
        if ($ForcePasswordChange) {
            $adsiUser = [ADSI]"WinNT://localhost/$username,user"
            $adsiUser.psbase.InvokeSet("PasswordExpired", 1)
            $adsiUser.CommitChanges()
            Write-Host "  -> Установлено требование смены пароля при следующем входе." -ForegroundColor Green
        } else {
            Write-Host "  -> Пароль установлен как постоянный (смена не требуется)." -ForegroundColor Gray
        }
        
        # Шаг 3: Добавление в группы, если они были указаны
        if ($Groups.Count -gt 0) {
            foreach ($groupName in $Groups) {
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
