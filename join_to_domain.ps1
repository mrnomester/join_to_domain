# Функция для проверки прав администратора
function Test-IsAdmin {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Проверяем, запущен ли скрипт с правами администратора
if (-not (Test-IsAdmin)) {
    Write-Host "Скрипт не запущен с правами администратора. Перезапускаем с повышенными правами..."
    
    # Получаем полный путь к текущему скрипту
    $scriptPath = $MyInvocation.MyCommand.Definition
    
    # Запускаем скрипт с повышенными правами
    Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs
    exit
}

# Путь к файлу-маркеру (общедоступное расположение)
$markerPath = "C:\Users\Public\join_to_domain.marker"

# Проверка, был ли скрипт уже выполнен
if (Test-Path $markerPath) {
    exit 0
}

# Функция для безопасного ввода имени компьютера
function Get-ValidComputerName {
    do {
        $inputName = Read-Host "Введите уникальное имя компьютера"
        if ([string]::IsNullOrWhiteSpace($inputName)) {
            Write-Host "Имя компьютера не может быть пустым. Попробуйте снова."
        } else {
            return $inputName
        }
    } while ($true)
}

# Функция для безопасного ввода учетных данных
function Get-ValidCredentials {
    do {
        $cred = Get-Credential -Message "Учетные данные администратора домена"
        if ($null -eq $cred) {
            Write-Host "Учетные данные не могут быть пустыми. Попробуйте снова."
        } else {
            return $cred
        }
    } while ($true)
}

# Инициализация переменных для хранения данных
$computerName = $null
$credential = $null

# Основной код скрипта
do {
    try {
        # Если имя компьютера еще не введено, запросим его
        if ([string]::IsNullOrWhiteSpace($computerName)) {
            $computerName = Get-ValidComputerName
        }

        # Если учетные данные еще не введены, запросим их
        if ($null -eq $credential) {
            Write-Host "Введите учетные данные администратора домена avuar.local"
            $credential = Get-ValidCredentials
        }

        # Параметры домена
        $domain = "domain.local"

        # Присоединение к домену и переименование
        Add-Computer -DomainName $domain -Credential $credential -NewName $computerName -ErrorAction Stop -Restart
        Write-Host "Компьютер успешно добавлен в домен $domain с именем $computerName."

        # Создание маркера выполнения
        New-Item -Path $markerPath -ItemType File -Force | Out-Null
        Write-Host "Маркер выполнения создан: $markerPath"

        # Выход из цикла, если все успешно
        break

    } catch {
        # Вывод ошибки
        Write-Host "Ошибка при выполнении скрипта: $_"

        # Запрос действия пользователя
        $choice = Read-Host "Выберите действие: 0 - повторить с новым вводом, 1 - повторить без нового ввода, 2 - выйти"
        switch ($choice) {
            "0" {
                # Повторить с новым вводом: очищаем сохраненные данные
                $computerName = $null
                $credential = $null
                continue
            }
            "1" {
                # Повторить без нового ввода: используем ранее введенные данные
                continue
            }
            "2" {
                # Выйти
                exit 1
            }
            default {
                Write-Host "Неверный выбор. Повторите попытку."
                continue
            }
        }
    }
} while ($true)