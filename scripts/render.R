# Render without downloading data or fitting a model.
if (!file.exists("config.R")) stop("Run from the project root.")
quarto <- Sys.getenv("QUARTO_BIN", unset = Sys.which("quarto"))
if (!nzchar(quarto)) {
  bundled <- "/Applications/RStudio.app/Contents/Resources/app/quarto/bin/quarto"
  if (file.exists(bundled)) quarto <- bundled
}
if (!nzchar(quarto)) stop("Install Quarto or set QUARTO_BIN to its executable.")
if (dir.exists(".Rlib")) Sys.setenv(R_LIBS_USER = normalizePath(".Rlib"))
Sys.setenv(LANG = "en_US.UTF-8", LC_ALL = "en_US.UTF-8")
status <- system2(quarto, c("render", "dashboard/index.qmd"))
if (status != 0L) stop("Quarto rendering failed.")
cat("Dashboard:", normalizePath("dist/dashboard/index.html", mustWork = TRUE), "\n")
