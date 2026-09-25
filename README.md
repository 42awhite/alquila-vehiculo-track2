# Alquila Vehículo S.L. — Track II (Salesforce)

Proyecto técnico desarrollado como parte del **Talent Day de NTT Data**, sobre la base funcional construida en el Track I. Implementa 6 requerimientos de negocio sobre un sistema de gestión de alquiler de vehículos, cubriendo automatización con Apex, procesos declarativos, componentes Lightning y buenas prácticas de arquitectura Enterprise en Salesforce.

## Stack técnico

- **Apex** (Triggers, Classes, Queueable, Tests)
- **Lightning Web Components (LWC)**
- **Approval Processes** (nativo, con Flow subyacente)
- **Record-Triggered Flow**
- **Custom Metadata Types**
- **Salesforce DX** para desarrollo y despliegue

## Patrón de arquitectura

Todo el código sigue el patrón **Trigger → Handler → Service**, con estricta separación de responsabilidades:

- El **Trigger** (`VRT_TRG_Rental`) no contiene lógica, únicamente delega según el contexto de ejecución.
- El **Handler** (`VRT_TRG_RentalHandler`) orquesta qué se ejecuta en cada evento (`before`/`after`, `insert`/`update`).
- Los **Services** (`VRT_PricingEngineService`, `VRT_AvailabilityService`) contienen la lógica de negocio pura, reutilizable desde múltiples puntos de entrada (triggers, controllers de LWC, procesos async).

Principios aplicados de forma consistente: bulkificación estricta (cero SOQL/DML dentro de bucles), manejo explícito de errores, y separación entre lógica de cálculo y lógica de persistencia.

## Módulos implementados

| # | Módulo | Resumen |
|---|---|---|
| 4.1 | **Sistema de Precios Dinámicos** | Cálculo automático del Coste Total según tipo de vehículo, temporada, fidelidad del cliente y penalización por retraso. Tarifas administrables vía Custom Metadata Type (`VRT_PricingRule__mdt`). |
| 4.2 | **Control de Disponibilidad de Flota** | Bloquea la creación/edición de Alquileres con fechas solapadas para un mismo vehículo, incluyendo detección de conflictos dentro de un mismo lote de carga masiva. |
| 4.3 | **Sistema de Aprobaciones Financieras** | Aprobación escalonada según importe (simple &gt;3.000€, doble &gt;10.000€) mediante dos Approval Processes nativos, disparados automáticamente por un Record-Triggered Flow. |
| 4.4 | **Consola Operativa (LWC)** | Componente Lightning integrado en la página de Account: listado de alquileres activos, filtro y orden, creación con simulación de precio previa al guardado, y feedback en tiempo real. |
| 4.5 | **Facturación Automática** | Al completar un Alquiler, un proceso `Queueable` genera la Factura correspondiente, intenta notificar por email al cliente, y registra la trazabilidad completa en un Log de Proceso — sin bloquear la operación principal del usuario. |
| 4.6 | **Buscador Global de Flota** | Componente Lightning en la Home Page: búsqueda de vehículos por texto parcial (Matrícula, Marca, Modelo), con navegación directa a la ficha del resultado. |

## Modelo de datos (objetos nuevos sobre el Track I)

| Objeto | Tipo | Propósito |
|---|---|---|
| `VRT_PricingRule__mdt` | Custom Metadata Type | Tarifas administrables por Tipo de Vehículo + Temporada |
| `VRT_Invoice__c` | Custom Object | Facturas generadas automáticamente al completar un Alquiler |
| `VRT_ProcessLog__c` | Custom Object | Trazabilidad de los procesos asíncronos (éxito/error por paso) |

## Clases Apex principales

- `VRT_PricingEngineService` — motor de cálculo de precios (4.1), reutilizado también por la simulación de 4.4
- `VRT_AvailabilityService` — validación de solapamiento de fechas (4.2)
- `VRT_RentalConsoleController` — controller `@AuraEnabled` de la Consola Operativa (4.4)
- `VRT_InvoicingQueueable` — proceso asíncrono de facturación (4.5)
- `VRT_VehicleSearchController` — controller `@AuraEnabled` del Buscador Global (4.6)

Cada clase de lógica de negocio cuenta con su correspondiente clase de test (`*_Test`), con cobertura ≥85% y escenarios positivos, negativos y de carga masiva.

## Despliegue

```bash
sf project deploy start --source-dir force-app
```

## Ejecutar los tests

Desde VS Code: `Ctrl+Shift+P` → `SFDX: Run Apex Tests`, o desde Developer Console → Overall Code Coverage para ver el detalle por clase.

## Autoría

Desarrollado por Ana Blanco Mota como parte del proceso de selección de NTT Data (Talent Day).