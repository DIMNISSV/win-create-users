<#
.SYNOPSIS
    Создает или удаляет локальных пользователей из текстового файла.
.DESCRIPTION
    Скрипт работает в двух режимах:
    1. РЕЖИМ СОЗДАНИЯ (по умолчанию): Читает файл формата "Имя<ТАБ>Полное имя<ТАБ>Описание",
       создает пользователей, добавляет в группы и управляет политикой смены пароля.
    2. РЕЖИМ УДАЛЕНИЯ (с ключом -Delete): Читает тот же файл, находит пользователей по колонке "Имя"
       и полностью удаляет их, включая папку профиля.

.PARAMETER PathToFile
    Полный путь к текстовому файлу с пользователями.

.PARAMETER Delete
    (Переключатель) Если указан, скрипт переходит в режим удаления пользователей.

.PARAMETER Groups
    (Режим создания) Список групп через запятую, в которые нужно добавить пользователей.

.PARAMETER ForcePasswordChange
    (Режим создания) Требовать смену пароля при первом входе. По умолчанию $true.

.EXAMPLE
    # Пример 1: СОЗДАТЬ пользователей и добавить в группу
    .\Create-Or-Delete-Users.ps1 -PathToFile .\users.txt -Groups "Remote Desktop Users"

.EXAMPLE
    # Пример 2: УДАЛИТЬ всех пользователей, перечисленных в том же файле
    .\Create-Or-Delete-Users.ps1 -PathToFile .\users.txt -Delete
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$PathToFile,

    [Parameter(Mandatory=$false)]
    [switch]$Delete,

    [Parameter(Mandatory=$false)]
    [string[]]$Groups,

    [Parameter(Mandatory=$false)]
    [bool]$ForcePasswordChange
)

# === КОМАНДЫ НАЧИНАЮТСЯ ЗДЕСЬ, ПОСЛЕ PARAM ===
$OutputEncoding = [System.Text.Encoding]::UTF8

# Надежная инициализация параметров для режима создания
if ($null -eq $Groups) {
    $Groups = @()
}
if (-not $PSBoundParameters.ContainsKey('ForcePasswordChange')) {
    $ForcePasswordChange = $true
}


if (-not (Test-Path $PathToFile)) {
    Write-Host "Ошибка: Файл не найден по пути: '$PathToFile'" -ForegroundColor Red
    exit
}

# Читаем файл один раз
$users = Import-Csv -Path $PathToFile -Delimiter "`t" -Encoding UTF8


# ===================================================================
#               ОСНОВНОЙ ПЕРЕКЛЮЧАТЕЛЬ РЕЖИМОВ
# ===================================================================

if ($Delete) {
    # ------------------- РЕЖИМ УДАЛЕНИЯ -------------------
    Write-Host "--- РЕЖИМ: УДАЛЕНИЕ ПОЛЬЗОВАТЕЛЕЙ ---" -ForegroundColor Yellow

    foreach ($user in $users) {
        $username = $user."Имя"
        if ([string]::IsNullOrWhiteSpace($username)) { continue }

        $userObject = Get-LocalUser -Name $username -ErrorAction SilentlyContinue
        if (-not $userObject) {
            Write-Host "Пользователь '$username' не найден. Пропускаем." -ForegroundColor Gray
            continue
        }

        Write-Host "Начинаю удаление пользователя '$username'..."
        try {
            # Шаг 1: Найти и удалить папку профиля (самое важное)
            $userProfile = Get-CimInstance -ClassName Win32_UserProfile | Where-Object { $_.SID -eq $userObject.SID.Value }
            if ($userProfile) {
                Write-Host "  -> Найдена папка профиля: $($userProfile.LocalPath). Удаляю..."
                Remove-Item -Path $userProfile.LocalPath -Recurse -Force
                Write-Host "  -> Папка профиля удалена." -ForegroundColor Green
            }

            # Шаг 2: Удалить саму учетную запись
            Remove-LocalUser -Name $username -Confirm:$false
            Write-Host "УСПЕХ: Пользователь '$username' и его профиль были полностью удалены." -ForegroundColor Green
        }
        catch {
            Write-Host "ОШИБКА при удалении пользователя '$username':" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
        }
        Write-Host ""
    }

} else {
    # ------------------- РЕЖИМ СОЗДАНИЯ -------------------
    Write-Host "--- РЕЖИМ: СОЗДАНИЕ ПОЛЬЗОВАТЕЛЕЙ ---" -ForegroundColor Cyan

    foreach ($user in $users) {
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
            New-LocalUser -Name $username -Password $securePassword -FullName $fullName -Description "Создан скриптом $(Get-Date)"
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
                    } else {
                        Write-Host "  -> ПРЕДУПРЕЖДЕНИЕ: Группа '$groupName' не найдена." -ForegroundColor Yellow
                    }
                }
            }
        }
        catch {
            Write-Host "ОШИБКА при обработке пользователя '$username':" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
        }
        Write-Host ""
    }
}
