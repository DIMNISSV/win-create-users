<#
.SYNOPSIS
    Создает локальных пользователей Windows из текстового файла.

.DESCRIPTION
    Скрипт читает текстовый файл, где каждая строка содержит имя пользователя и пароль, разделенные табуляцией.
    Он создает локальных пользователей и, используя ADSI, устанавливает требование смены пароля при первом входе.

.PARAMETER PathToFile
    Полный путь к текстовому файлу. Файл должен быть в формате: имя_пользователя<ТАБ>пароль.

.EXAMPLE
    .\Create-Users.ps1 -PathToFile "C:\temp\users.txt"
    Эта команда запустит скрипт и будет использовать файл users.txt для создания пользователей.
#>
param(
    [Parameter(Mandatory=$true, HelpMessage="Укажите полный путь к текстовому файлу с пользователями.")]
    [string]$PathToFile
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

# 2. Чтение файла и создание пользователей
$users = Import-Csv -Path $PathToFile -Delimiter "`t" -Header "UserName", "Password"

foreach ($user in $users) {
    if ([string]::IsNullOrWhiteSpace($user.UserName)) {
        continue
    }

    $username = $user.UserName.Trim() # Добавим Trim на всякий случай
    $password = $user.Password

    if (Get-LocalUser -Name $username -ErrorAction SilentlyContinue) {
        Write-Host "Пользователь '$username' уже существует. Пропускаем." -ForegroundColor Yellow
        continue
    }

    try {
        # Шаг 1: Преобразование пароля и создание пользователя
        $securePassword = ConvertTo-SecureString -String $password -AsPlainText -Force
        New-LocalUser -Name $username -Password $securePassword -FullName $username -Description "Создан скриптом $(Get-Date)"

        # === НАДЕЖНЫЙ МЕТОД ЧЕРЕЗ ADSI ===
        # Шаг 2: Получаем доступ к пользователю через ADSI
        $adsiUser = [ADSI]"WinNT://localhost/$username,user"
        
        # Шаг 3: Устанавливаем свойство 'PasswordExpired' в 1. Это заставит систему
        # потребовать смену пароля при следующем входе.
        $adsiUser.psbase.InvokeSet("PasswordExpired", 1)
        
        # Шаг 4: Сохраняем изменения
        $adsiUser.CommitChanges()
        # === КОНЕЦ БЛОКА ADSI ===

        Write-Host "УСПЕХ: Пользователь '$username' успешно создан. Установлено требование смены пароля." -ForegroundColor Green
    }
    catch {
        Write-Host "ОШИБКА при создании пользователя '$username':" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}

Write-Host "`nОбработка завершена." -ForegroundColor Cyan
