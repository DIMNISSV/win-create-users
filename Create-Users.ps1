<#
.SYNOPSIS
    Создает локальных пользователей из текстового файла формата "Имя<ТАБ>Полное имя<ТАБ>Описание".
.DESCRIPTION
    Скрипт читает текстовый файл в кодировке UTF-8. В качестве пароля используется
    значение из колонки "Описание".
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$PathToFile,

    [Parameter(Mandatory=$false)]
    [string[]]$Groups,

    [Parameter(Mandatory=$false)]
    [bool]$ForcePasswordChange
)

# === КОМАНДЫ НАЧИНАЮТСЯ ЗДЕСЬ, ПОСЛЕ PARAM ===
$OutputEncoding = [System.Text.Encoding]::UTF8

# Надежная инициализация параметров
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

Write-Host "Начинаю обработку файла: $PathToFile" -ForegroundColor Cyan

# Читаем CSV-файл с разделителем-табуляцией, используя кодировку UTF8
$users = Import-Csv -Path $PathToFile -Delimiter "`t" -Encoding UTF8

foreach ($user in $users) {
    # Получаем данные из колонок по их именам
    $username = $user."Имя"
    $fullName = $user."Полное имя"
    $password = $user."Описание" # Пароль находится в колонке "Описание"

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
                    Write-Host "  -> ПРЕДУПРЕЖДЕНИЕ: Группа '$groupName' не найдена. Пропускаем." -ForegroundColor Yellow
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
