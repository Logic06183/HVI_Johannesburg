@echo off
set R_HOME=C:\Users\CraigParker\AppData\Local\Programs\R\R-4.4.1
set PATH=%R_HOME%\bin;%PATH%

echo Running R Markdown analysis...
"C:\Users\CraigParker\AppData\Local\Programs\R\R-4.4.1\bin\x64\R.exe" -e "rmarkdown::render('Consolidated_Analysis_HVI_Joburg.Rmd', output_format = 'html_document')"

if errorlevel 1 (
    echo Error running analysis
    pause
) else (
    echo Analysis completed successfully
    echo Opening output file...
    start Consolidated_Analysis_HVI_Joburg.html
)
