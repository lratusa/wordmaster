@echo off
REM WordMaster Pre-Release Test Suite
REM Runs tests in phases, stops on first failure.

echo ============================================
echo   WordMaster Pre-Release Test Suite
echo ============================================
echo.

echo [Phase 1/4] Unit Tests (models, enums, pure logic)
echo --------------------------------------------------
flutter test test/unit/ --reporter expanded
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo FAILED: Unit tests did not pass.
    exit /b 1
)
echo.

echo [Phase 2/4] Repository Tests (in-memory SQLite)
echo --------------------------------------------------
flutter test test/repository/ --reporter expanded
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo FAILED: Repository tests did not pass.
    exit /b 1
)
echo.

echo [Phase 3/4] Integration Tests (full flows)
echo --------------------------------------------------
flutter test test/integration/ --reporter expanded
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo FAILED: Integration tests did not pass.
    exit /b 1
)
echo.

echo [Phase 4/4] Widget Tests (existing)
echo --------------------------------------------------
flutter test test/widget/ --reporter expanded
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo FAILED: Widget tests did not pass.
    exit /b 1
)
echo.

echo ============================================
echo   ALL TESTS PASSED
echo ============================================
