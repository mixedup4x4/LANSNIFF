REM Author:  Steven R. Stepp
REM Created: 10/29/2010
REM TESTED ON - Windows 7 Professional 64-bit
REM
REM -----------------------------------------------------------------------
REM 12/19/2012  Changed to use regular comments from the non-standard double colons
REM
@echo off
cls
setlocal enableextensions
SET VERSION=0.2

REM -----------------------------------------------------------------------
REM Start Main
REM -----------------------------------------------------------------------
	CALL :setFull FALSE
	CALL :setSilent FALSE
	CALL :setNoLog FALSE
	CALL :setInactiveString
	CALL :setUnknownString
	CALL :setLogFilename
	CALL :setKill TRUE

	REM Grab and store the switches from the command line.
	:Loop
		IF [%1]==[] GOTO Continue
		   IF /I [%1] EQU [/FULL] CALL :setFull TRUE
		   IF /I [%1] EQU [/SILENT] CALL :setSilent TRUE
		   IF /I [%1] EQU [/NOLOG] CALL :setNoLog TRUE
		   IF /I [%1] EQU [/S] CALL :setStartIP %2
		   IF /I [%1] EQU [/E] CALL :setEndIP %2
		   IF /I [%1] EQU [/I] CALL :setInactiveString %2
		   IF /I [%1] EQU [/U] CALL :setUnknownString %2
		   IF /I [%1] EQU [/LF] CALL :setLogFilename %2
		   IF /I [%1] EQU [/?] CALL :setKill TRUE
		SHIFT
		GOTO Loop
	:Continue

	REM Initialize the log files
	CALL :init
	
	REM If no command line switches are passed in or a question mark then 
	REM display the usage and exit the batch file.
	IF /I [%KILL%] EQU [TRUE] CALL :echoUsage
	IF /I [%KILL%] EQU [TRUE] GOTO :end
	
	REM Scan and process the given IP range
	CALL :process
	
	REM Finish the output to screen and log
	CALL :wrap_up
	
	endlocal
	GOTO :end
REM -----------------------------------------------------------------------
REM End Main
REM -----------------------------------------------------------------------


REM -----------------------------------------------------------------------
REM FUNCTIONS
REM -----------------------------------------------------------------------

	:echoUsage
		echo.
		echo. LANSNIFF is a utility to scan your private network to determine what IP
		echo. addresses are being used and if possible what the name of the device is at
		echo. that address.
		echo.                                                           
		echo. ---------------------------------------------------------------------------
		echo. USAGE:
		echo.          LANSNIFF /S start_ip /E end_ip [/FULL] [/SILENT] [/NOLOG]
		echo.
		echo.          EX: LANSNIFF /S 192.168.0.1 /E 192.168.0.5 /FULL
		echo.          EX: LANSNIFF /S 10.0.0.0 /E 10.0.2.255
		echo.
		echo. ---------------------------------------------------------------------------
		echo. COMMAND LINE SWITCHES:
		echo.
		echo. /S       Starting IP Address. The utility will begin with this IP
		echo.          address and advance through each IP address until the End IP
		echo.          Address is reached. IP Address must be in the private available
		echo.          domains, the utility will skip any not within this range. REQUIRED
		echo.
		echo. /E       Ending IP Address. The utility will end when this IP address is
		echo.          reached. IP Address must be in the private available domains, the
		echo.          utility will skip any not within this range. REQUIRED
		echo.
		echo. /FULL    Will include unreachable IP addresses in the log file. Default is
		echo.          to skip these addresses in the log. [OPTIONAL]
		echo.
		echo. /SILENT  Keep batch file from outputting to the screen.
		echo.
		echo. /NOLOG   Keep batch file from outputting to the log file.
		echo.
		echo. /I       Set string to identify inactive IP addresses. The string must be
		echo.          wrapped with double quotes if it contains spaces. Default is -n/a-
		echo.
		echo. /U       Set string to identify unknown devices. The string must be wrapped
		echo.          with double quotes if it contains spaces. Default is -unknown_dev-
		echo.
		echo. /LF      Specify a path and filename to use for the log.
		echo.
		echo. ---------------------------------------------------------------------------
		echo. OUTPUT:
		echo.          The screen will display each IP address as it attempts to identify
		echo.          if its a device and the name. A log file will also be written
		echo.          with the results. The switch /FULL will include IP addresses that
		echo.          were unreachable, which by default are excluded from the log.
		echo.
		echo. ---------------------------------------------------------------------------
		
		CALL :setKill TRUE
	GOTO :eof

	:setKill
		IF /I [%1] == [TRUE] SET KILL=TRUE
		IF /I [%1] == [FALSE] SET KILL=FALSE
	GOTO :eof

	:setFull
		IF /I [%1] == [TRUE] SET FULL=TRUE
		IF /I [%1] == [FALSE] SET FULL=FALSE
	GOTO :eof

	:setSilent
		IF /I [%1] == [TRUE] SET SILENT=TRUE
		IF /I [%1] == [FALSE] SET SILENT=FALSE
	GOTO :eof
	
	:setNoLog
		IF /I [%1] == [TRUE] SET NOLOG=TRUE
		IF /I [%1] == [FALSE] SET NOLOG=FALSE
	GOTO :eof
	
	:setFound
		IF /I [%1] == [TRUE] SET FOUND=TRUE
		IF /I [%1] == [FALSE] SET FOUND=FALSE
	GOTO :eof

	:setStartIP
		IF /I [%1] NEQ [] SET START_IP=%1
		IF /I [%1] NEQ [] CALL :setKill FALSE
	GOTO :eof

	:setEndIP
		IF /I [%1] NEQ [] SET END_IP=%1
		IF /I [%1] NEQ [] CALL :setKill FALSE
	GOTO :eof

	:setInactiveString
		SET INACTIVE_STR=-n/a-
		IF /I [%1] NEQ [] SET INACTIVE_STR=%1
	GOTO :eof
	
	:setUnknownString
		SET UNKNOWN_STR=-unknown_dev-
		IF /I [%1] NEQ [] SET UNKNOWN_STR=%1
	GOTO :eof
	
	:setLogFilename
		SET LOGFILE=
		IF /I [%1] NEQ [] SET LOGFILE=%1
	GOTO :eof
	
	:setIPValid
		IF /I [%1] == [TRUE] SET IP_VALID=TRUE
		IF /I [%1] == [FALSE] SET IP_VALID=FALSE
	GOTO :eof

	:setComputerName
		SET COMPUTER_NAME=
		IF /I [%1] NEQ [] SET COMPUTER_NAME=%1
	GOTO :eof

	:isIPValid
		FOR /F "tokens=1,2,3,4 delims=." %%A IN ("%1") DO SET IP_A=%%A&SET IP_B=%%B&SET IP_C=%%C&SET IP_D=%%D
		
		REM Private network ranges
		REM   10.0.0.0    - 10.255.255.255
		REM   172.16.0.0  - 172.31.255.255
		REM   192.168.0.0 - 192.168.255.255
		REM SUBNET A
		REM   CONTINUE isn't used, but we need to do some command so the batch file doesn't error
		IF /I [%IP_A%] EQU [10] (
			SET CONTINUE=TRUE	
		) ELSE (
			IF /I [%IP_A%] EQU [172] (
				REM do nothing
				SET CONTINUE=TRUE
			) ELSE (
				IF /I [%IP_A%] EQU [192] (
					REM do nothing
					SET CONTINUE=TRUE
				) ELSE (
					REM Not within the private network range
					CALL :setIPValid FALSE
				)
			)
		)
		
		REM SUBNET B
		IF /I [%IP_A%] EQU [10] (
			IF /I %IP_B% LSS 0 CALL :setIPValid FALSE
			IF /I %IP_B% GTR 255 CALL :setIPValid FALSE
		)
		IF /I [%IP_A%] EQU [172] (
			IF /I %IP_B% LSS 16 CALL :setIPValid FALSE
			IF /I %IP_B% GTR 31 CALL :setIPValid FALSE
		)
		IF /I [%IP_A%] EQU [192] (
			IF /I [%IP_B%] NEQ [168] CALL :setIPValid FALSE
		)
		REM SUBNET C
		IF /I [%IP_A%] EQU [10] (
			IF /I %IP_C% LSS 0 CALL :setIPValid FALSE
			IF /I %IP_C% GTR 255 CALL :setIPValid FALSE
		)
		IF /I [%IP_A%] EQU [172] (
			IF /I %IP_C% LSS 0 CALL :setIPValid FALSE
			IF /I %IP_C% GTR 255 CALL :setIPValid FALSE
		)
		IF /I [%IP_A%] EQU [192] (
			IF /I %IP_C% LSS 0 CALL :setIPValid FALSE
			IF /I %IP_C% GTR 255 CALL :setIPValid FALSE
		)
		REM SUBNET D
		IF /I [%IP_A%] EQU [10] (
			IF /I %IP_D% LSS 0 CALL :setIPValid FALSE
			IF /I %IP_D% GTR 255 CALL :setIPValid FALSE
		)
		IF /I [%IP_A%] EQU [172] (
			IF /I %IP_D% LSS 0 CALL :setIPValid FALSE
			IF /I %IP_D% GTR 255 CALL :setIPValid FALSE
		)
		IF /I [%IP_A%] EQU [192] (
			IF /I %IP_D% LSS 0 CALL :setIPValid FALSE
			IF /I %IP_D% GTR 255 CALL :setIPValid FALSE
		)
	GOTO :eof

	:getStrLength
		SET str=%1
		echo %str%> "%temp%\st.txt" 
		for %%a in (%temp%\st.txt) do set /a len=%%~za & set /a len -=3 & del "%temp%\st.txt"
		SET STR_LENGTH=%len%
	GOTO :eof

	:init
		IF /I [%NOLOG%] EQU [FALSE] (
			REM Set variable for filename of log
			IF /I [%LOGFILE%] EQU [] SET LOGFILE=lansniff_v%VERSION%.log
		)
		SET Now=%date%
		SET StartTime=%time%
		CALL :tokenize_date %Now%
	GOTO :eof

	:process
		REM Lets check to see that we have a starting and ending IP address.
		CALL :setIPValid TRUE
		CALL :isIPValid %START_IP%
		IF /I [%IP_VALID%] == [FALSE] (
			REM Invalid IP Address, message the user and exit the batch file
			ECHO.
			ECHO Invalid Starting IP Address
			ECHO.
			CALL :echoUsage
			GOTO :end
		)
		CALL :isIPValid %END_IP%
		IF /I [%IP_VALID%] == [FALSE] (
			REM Invalid IP Address, message the user and exit the batch file
			ECHO.
			ECHO Invalid Ending IP Address
			ECHO.
			CALL :echoUsage
			GOTO :end
		)
		
		IF /I [%NOLOG%] EQU [FALSE] (
			REM Create log if doesn't exist, add header to log
			IF NOT EXIST "%LOGFILE%" ECHO LANSNIFF - Log file>"%LOGFILE%"
			ECHO.>>"%LOGFILE%"
			ECHO Date       Time		IP		Hostname>>"%LOGFILE%"
			ECHO ------------------------------------------------------------->>"%LOGFILE%"
		)
		
		REM Parse the start and end IP addresses into individual subnets
		FOR /F "tokens=1,2,3,4 delims=." %%A IN ("%START_IP%") DO SET START_IP_A=%%A&SET START_IP_B=%%B&SET START_IP_C=%%C&SET START_IP_D=%%D
		FOR /F "tokens=1,2,3,4 delims=." %%A IN ("%END_IP%") DO SET END_IP_A=%%A&SET END_IP_B=%%B&SET END_IP_C=%%C&SET END_IP_D=%%D
		
		REM For simplictiy, we will only allow an IP range where the first subnet is the same in
		REM both the starting and ending IP addresses
		IF /I [%START_IP_A%] NEQ [%END_IP_A%] (
			ECHO.
			ECHO Both the starting and ending IP addresses must be in the same
			ECHO private network range.
			ECHO.
			CALL :echoUsage
			GOTO :end
		)
		
		REM Loop for each subnet
		FOR /L %%A IN (%START_IP_A%,1,%END_IP_A%) DO (
			FOR /L %%B IN (%START_IP_B%,1,%END_IP_B%) DO (
				FOR /L %%C IN (%START_IP_C%,1,%END_IP_C%) DO (
					FOR /L %%D IN (%START_IP_D%,1,%END_IP_D%) DO (
						REM process the IP Address
						CALL :process_ip %%A %%B %%C %%D
					)
				)
			)
		)
		
	GOTO :eof

	:process_ip
		REM Process IP Address

		SET IP_ADDRESS=%1.%2.%3.%4
		
		REM Start ComputerName as blank
		CALL :setComputerName
		
		CALL :setFound FALSE
		
		REM First we test to see if the IP address is active before we attempt to lookup a device name
		FOR /F "tokens=2 delims= " %%A IN ('PING %IP_ADDRESS% -n 1 -w 3 ^| FIND "TTL="') DO CALL :setFound TRUE
		
		REM If IP Address was active then lookup device name and save as ComputerName
		IF [%FOUND%]==[TRUE] (FOR /F "tokens=2 delims= " %%B IN ('PING -a %IP_ADDRESS% -n 1 -w 100 ^| FIND "[%IP_ADDRESS%]"') DO CALL :setComputerName %%B)
		
		REM If IP Address was NOT active then save ComputerName as inactive address
		IF [%FOUND%]==[FALSE] (
			CALL :setComputerName %INACTIVE_STR%
		)
		
		REM Check if ComputerName is blank, if so save ComputerName as an unknown device
		IF [%COMPUTER_NAME%]==[] (
			CALL :setComputerName %UNKNOWN_STR%
		)
		
		REM Output results to file
		IF /I [%NOLOG%] EQU [FALSE] (
			IF [%FULL%]==[TRUE] (	
				ECHO %YEAR%-%MONTH%-%DAY% %time%	%IP_ADDRESS%	%COMPUTER_NAME%	>>"%LOGFILE%"
			) ELSE (
				IF /I [%COMPUTER_NAME%] NEQ [%INACTIVE_STR%]	ECHO %YEAR%-%MONTH%-%DAY% %time%	%IP_ADDRESS%	%COMPUTER_NAME%	>>"%LOGFILE%"
			)
		)

		REM Output results to screen, unless in SILENT mode
		IF /I [%SILENT%] EQU [FALSE] ECHO %YEAR%-%MONTH%-%DAY% %time%	%IP_ADDRESS%	%COMPUTER_NAME%

	GOTO :eof

	:tokenize_date
		REM assuming date format Tue 09/20/2010
		setlocal enableextensions
		SET arg=%2
		SET YEAR=%arg:~6,4%
		SET MONTH=%arg:~0,2%
		SET DAY=%arg:~3,2%
		endlocal&set YEAR=%YEAR%&set MONTH=%MONTH%&set DAY=%DAY%
	GOTO :eof

	:wrap_up
		IF /I [%SILENT%] EQU [FALSE] (
			ECHO.
			ECHO Complete.
		)
		
		SET Now=%date%
		CALL :tokenize_date %Now%
		SET EndTime=%time%

		IF /I [%NOLOG%] EQU [FALSE] (
			ECHO.>>"%LOGFILE%"
			ECHO %YEAR%-%MONTH%-%DAY% %EndTime% - COMPLETE>>"%LOGFILE%"
		)
	GOTO :eof

REM -----------------------------------------------------------------------
REM END FUNCTIONS
REM -----------------------------------------------------------------------

REM -----------------------------------------------------------------------
REM END OF BATCH FILE
REM -----------------------------------------------------------------------
:end
