<#
.SYNOPSIS
    Создает, удаляет или обновляет локальных пользователей из текстового файла.
.DESCRIPTION
    Скрипт работает в трех режимах:
    1. СОЗДАНИЕ (по умолчанию): Создает пользователей, добавляет в группы, управляет паролем.
    2. УДАЛЕНИЕ (-Delete): Полностью удаляет пользователей и их профили.
    3. ОБНОВЛЕНИЕ (-Update): Обновляет описание и пароль у существующих пользователей.

.PARAMETER PathToFile
    Полный путь к текстовому файлу с пользователями.

.PARAMETER Delete
    (Переключатель) Режим удаления пользователей.

.PARAMETER Update
    (Переключатель) Режим обновления пользователей.

.PARAMETER Groups
    (Режим создания) Группы для добавления новых пользователей.

.PARAMETER ForcePasswordChange
    (Режим создания) Требовать смену пароля при первом входе.

.EXAMPLE
    # 1. СОЗДАТЬ пользователей из файла
    .\Create-Users.ps1 -PathToFile .\users.txt -Groups "Remote Desktop Users"

.EXAMPLE
    # 2. ОБНОВИТЬ описание и пароль у пользователей из этого же файла
    .\Create-Users.ps1 -PathToFile .\users.txt -Update

.EXAMPLE
    # 3. УДАЛИТЬ всех пользователей из этого же файла
    .\Create-Users.ps1 -PathToFile .\users.txt -Delete
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$PathToFile,
    [Parameter(Mandatory=$false)]
    [switch]$Delete,
    [Parameter(Mandatory=$false)]
    [switch]$Update,
    [Parameter(Mandatory=$false)]
    [string[]]$Groups,
    [Parameter(Mandatory=$false)]
    [bool]$ForcePasswordChange
)

# === КОМАНДЫ НАЧИНАЮТСЯ ЗДЕСЬ, ПОСЛЕ PARAM ===
$OutputEncoding = [System.Text.Encoding]::UTF8

# Надежная инициализация параметров
if ($null -eq $Groups) { $Groups = @() }
if (-not $PSBoundParameters.ContainsKey('ForcePasswordChange')) { $ForcePasswordChange = $true }


if (-not (Test-Path $PathToFile)) {
    Write-Host "Ошибка: Файл не найден по пути: '$PathToFile'" -ForegroundColor Red
    exit
}

# Читаем файл один раз
$usersFromFile = Import-Csv -Path $PathToFile -Delimiter "`t" -Encoding UTF8

# ===================================================================
#               ОСНОВНОЙ ПЕРЕКЛЮЧАТЕЛЬ РЕЖИМОВ
# ===================================================================

if ($Delete) {
    # ------------------- РЕЖИМ УДАЛЕНИЯ -------------------
    # (Логика без изменений)
    Write-Host "--- РЕЖИМ: УДАЛЕНИЕ ПОЛЬЗОВАТЕЛЕЙ ---" -ForegroundColor Yellow
    foreach ($user in $usersFromFile) {
        $username = $user."Имя"
        if ([string]::IsNullOrWhiteSpace($username)) { continue }
        $userObject = Get-LocalUser -Name $username -ErrorAction SilentlyContinue
        if (-not $userObject) {
            Write-Host "Пользователь '$username' не найден. Пропускаем." -ForegroundColor Gray
            continue
        }
        Write-Host "Начинаю удаление пользователя '$username'..."
        try {
            $userProfile = Get-CimInstance -ClassName Win32_UserProfile | Where-Object { $_.SID -eq $userObject.SID.Value }
            if ($userProfile) { Remove-Item -Path $userProfile.LocalPath -Recurse -Force; Write-Host "  -> Папка профиля удалена." -ForegroundColor Green }
            Remove-LocalUser -Name $username -Confirm:$false
            Write-Host "УСПЕХ: Пользователь '$username' и его профиль были полностью удалены." -ForegroundColor Green
        } catch { Write-Host "ОШИБКА при удалении '$username': $($_.Exception.Message)" -ForegroundColor Red }
        Write-Host ""
    }

} elseif ($Update) {
    # ------------------- НОВЫЙ РЕЖИМ ОБНОВЛЕНИЯ -------------------
    Write-Host "--- РЕЖИМ: ОБНОВЛЕНИЕ ПОЛЬЗОВАТЕЛЕЙ ---" -ForegroundColor Magenta

    foreach ($user in $usersFromFile) {
        $username = $user."Имя"
        $newPassword = $user."Описание"
        $newDescription = $newPassword
        if ([string]::IsNullOrWhiteSpace($username)) { continue }

        $userObject = Get-LocalUser -Name $username -ErrorAction SilentlyContinue
        if (-not $userObject) {
            Write-Host "Пользователь '$username' для обновления не найден. Пропускаем." -ForegroundColor Gray
            continue
        }

        Write-Host "Начинаю обновление пользователя '$username'..."
        try {
            $securePassword = ConvertTo-SecureString -String $newPassword -AsPlainText -Force
            # Обновляем пароль и описание одной командой
            Set-LocalUser -Name $username -Password $securePassword -Description $newDescription
            Write-Host "УСПЕХ: Пароль и описание для пользователя '$username' обновлены." -ForegroundColor Green
        } catch { Write-Host "ОШИБКА при обновлении '$username': $($_.Exception.Message)" -ForegroundColor Red }
        Write-Host ""
    }

} else {
    # ------------------- РЕЖИМ СОЗДАНИЯ -------------------
    # (Логика без изменений)
    Write-Host "--- РЕЖИМ: СОЗДАНИЕ ПОЛЬЗОВАТЕЛЕЙ ---" -ForegroundColor Cyan
    foreach ($user in $usersFromFile) {
        $username = $user."Имя"
        $fullName = $user."Полное имя"
        $password = $user."Описание"
        if ([string]::IsNullOrWhiteSpace($username)) { continue }

        if (Get-LocalUser -Name $username -ErrorAction SilentlyContinue) {
            Write-Host "Пользователь '$username' уже существует. Пропускаем." -ForegroundColor Yellow
            continue
        }
        try {
            $securePassword = ConvertTo-SecureString -String $password -AsPlainText -Force
            New-LocalUser -Name $username -Password $securePassword -FullName $fullName -Description $password
            Write-Host "УСПЕХ: Пользователь '$username' (Полное имя: '$fullName') успешно создан." -ForegroundColor Green

            if ($ForcePasswordChange) {
                $adsiUser = [ADSI]"WinNT://localhost/$username,user"
                $adsiUser.psbase.InvokeSet("PasswordExpired", 1)
                $adsiUser.CommitChanges()
                Write-Host "  -> Установлено требование смены пароля." -ForegroundColor Green
            }
            if ($Groups.Count -gt 0) {
                foreach ($groupName in $Groups) {
                    if (Get-LocalGroup -Name $groupName -ErrorAction SilentlyContinue) {
                        Add-LocalGroupMember -Group $groupName -Member $username
                        Write-Host "  -> Успешно добавлен в группу '$groupName'." -ForegroundColor Green
                    } else { Write-Host "  -> ПРЕДУПРЕЖДЕНИЕ: Группа '$groupName' не найдена." -ForegroundColor Yellow }
                }
            }
        } catch { Write-Host "ОШИБКА при создании '$username': $($_.Exception.Message)" -ForegroundColor Red }
        Write-Host ""
    }
}
