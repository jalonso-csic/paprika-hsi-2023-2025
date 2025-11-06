# 05_visualization — Publication figures from supervised reports (FX10 & FX17)

Genera **figuras listas para revista** a partir de los Excel producidos en `04_supervised`.

---

## Propósito

* **Matrices de confusión (tripanel)** por cámara, seleccionando automáticamente el mejor modelo desde `Summary_Metrics` (`CM_<best_model>`) o el primer `CM_*` disponible.
* **Perfiles de estabilidad VIP** en los tres preprocesados (MSC+1st, SNV+1st, SG 1st) con panel de media±rango y picos opcionales.

---

## Scripts (pares FX10/FX17)

```
code-matlab/05_visualization/
├─ plot_confusion_tripanel_fx10_autodetect.m
├─ plot_confusion_tripanel_fx17_autodetect.m
├─ plot_vip_stability_profiles_fx10.m
└─ plot_vip_stability_profiles_fx17.m
```

Layout y estilo comunes (Times New Roman, 10/12 pt, `tiledlayout` compacto).

---

## Entradas (desde el paso 04)

Coloca en la carpeta de trabajo (`pwd`) los **reportes normalizados**:

**FX10**

* `FX10_MSC_1_Derivada_Preproc_Report.xlsx`
* `FX10_SNV_1_Derivada_Preproc_Report.xlsx`
* `FX10_x1_Derivada_SG_Preproc_Report.xlsx`

**FX17**

* `FX17_MSC_1_Derivada_Preproc_Report.xlsx`
* `FX17_SNV_1_Derivada_Preproc_Report.xlsx`
* `FX17_x1_Derivada_SG_Preproc_Report.xlsx`

> Archivos archivados en Zenodo (**v2**): **10.5281/zenodo.17540888**.
> Tablas preprocesadas del paso 04: **10.5281/zenodo.17539563**.

---

## Salidas

Se guardan en el **directorio actual**:

* **Tripanel confusión**: `FX<cam>_confusion_matrices_tripanel.png` (600 dpi) y `.pdf` (vector).
* **Perfiles VIP**: se muestran en pantalla (ajusta el script si quieres exportar a archivo).

---

## Cómo ejecutar

1. Abrir MATLAB y `cd` a `code-matlab/05_visualization` (o a la carpeta con los reportes).
2. Ejecutar como funciones, sin argumentos:

   * FX10 confusión: `plot_confusion_tripanel_fx10_autodetect`
   * FX17 confusión: `plot_confusion_tripanel_fx17_autodetect`
   * FX10 VIP: `plot_vip_stability_profiles_fx10`
   * FX17 VIP: `plot_vip_stability_profiles_fx17`

---

## Comportamiento y parámetros clave

### Tripanel de confusión

* **Auto-detección**: lee `Summary_Metrics` → mayor `Mean_BalAcc` → `CM_<best_model>`. Si no existe, usa el primer `CM_*`.
* `asPercent`: `true` muestra % por fila; `false` muestra cuentas absolutas.
* Las etiquetas de clase se limpian de prefijos tipo `x2023 → 2023`.

### Perfiles VIP

* Lee `VIP_Stability` (`Wavelength_nm`, `Selection_Frequency`).
* Convierte a **%** si vienen en [0,1].
* Suaviza con **Savitzky–Golay** (`sgolayfilt`) o `movmean`.
* Panel A: tres perfiles con leyenda. Panel B: **media ± rango** y **picos** (si `findpeaks` disponible).
* Ajustables al inicio: `ylims`, `ytick_step`, `guide_lines`, `sgolay_ord`, `sgolay_win`, `min_prom`, `min_dist`, `show_peaks`.

---

## Requisitos

* MATLAB R2021a+ (probado). Sin toolboxes obligatorios para las figuras.
* Opcional: **Signal Processing Toolbox** (`sgolayfilt`, `findpeaks`).

---

## Problemas comunes

* **File not found**: verifica que los nombres coinciden exactamente con `*_Report.xlsx` (v2 de Zenodo) o ejecuta desde su carpeta.
* **No hay `CM_*`**: el paso 04 debe haber generado hojas de matrices; si faltan, vuelve a ejecutar el supervisado.
* **Etiquetas `x2023`**: los scripts ya eliminan el prefijo `x`; usa la variante “clean” solo si quieres fijar una hoja concreta.

---

## Cita

* **Supervised reports (entradas de este paso)**: **10.5281/zenodo.17540888** (v2)
* **Preprocesados para el paso 04**: **10.5281/zenodo.17539563**

> Por favor, cita ambos registros cuando utilices estas figuras.
