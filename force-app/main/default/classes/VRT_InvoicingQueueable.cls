public class VRT_InvoicingQueueable implements Queueable
{
    private Set<Id> rentalIds;

    // El constructor guarda los Ids recibidos para poder usarlos cuando Salesforce ejecute el job más tarde
    public VRT_InvoicingQueueable(Set<Id> rentalIds)
    {
        this.rentalIds = rentalIds;
    }

    // Punto de entrada del Queueable: orquesta las 4 fases del proceso de facturación
    public void execute(QueueableContext context)
    {
        // Fase 1: descartamos los Alquileres que ya tuvieran factura de antes
        Set<Id> rentalsToProcess = filterUninvoicedRentals(rentalIds);
        if (rentalsToProcess.isEmpty())
            return; // nada que facturar en este lote, todos ya tenían factura previa

        // Fase 2: traemos los datos reales que necesitamos (coste e email) de los que sí hay que facturar
        List<VRT_Rental__c> rentals = getRentalDetails(rentalsToProcess);

        // Esta lista la van rellenando los dos métodos siguientes, cada uno añadiendo sus propios logs
        List<VRT_ProcessLog__c> logsToInsert = new List<VRT_ProcessLog__c>();

        // Fase 3: creamos las facturas (con su propio manejo de errores independiente)
        generateInvoices(rentals, logsToInsert);

        // Fase 4: enviamos los emails (con su propio manejo de errores independiente, no afecta a las facturas)
        sendEmailNotifications(rentals, logsToInsert);

        // Guardamos todos los logs acumulados de ambas fases en una única operación al final
        insert logsToInsert;
    }

    // Prevención de duplicados: descarta cualquier Alquiler que ya tenga una Factura generada antes
    private Set<Id> filterUninvoicedRentals(Set<Id> candidateIds)
    {
        // Traemos las facturas YA existentes para cualquiera de los Alquileres candidatos
        List<VRT_Invoice__c> existingInvoices = [
            SELECT VRT_LKP_Rental__c
            FROM VRT_Invoice__c
            WHERE VRT_LKP_Rental__c IN :candidateIds
        ];

        // Construimos un set con los Ids de Alquiler que YA tienen factura, para poder consultarlo rápido después
        Set<Id> alreadyInvoicedIds = new Set<Id>();
        for (VRT_Invoice__c inv : existingInvoices)
        {
            alreadyInvoicedIds.add(inv.VRT_LKP_Rental__c);
        }

        // Nos quedamos solo con los candidatos que NO están en ese set — los que de verdad hay que facturar
        Set<Id> rentalsToProcess = new Set<Id>();
        for (Id rentalId : candidateIds)
        {
            if (!alreadyInvoicedIds.contains(rentalId))
            {
                rentalsToProcess.add(rentalId);
            }
        }
        return rentalsToProcess;
    }

    // Trae, de una sola consulta, todo lo necesario para facturar: coste total y email del cliente
    private List<VRT_Rental__c> getRentalDetails(Set<Id> ids)
    {
        // VRT_LKP_Account__r atraviesa la relación hasta el Account para traer su email en la misma consulta,
        // evitando una segunda SOQL solo para eso
        return [
            SELECT Id, VRT_DIV_TotalCost__c, VRT_LKP_Account__r.VRT_TXT_Email__c
            FROM VRT_Rental__c
            WHERE Id IN :ids
        ];
    }

    // Crea una Factura por cada Alquiler. Si el insert falla, registra un log de Error por cada uno
    // en vez de dejar que la excepción se propague sin dejar rastro
    private void generateInvoices(List<VRT_Rental__c> rentals, List<VRT_ProcessLog__c> logsToInsert)
    {
        // Construimos todas las Facturas en memoria primero, sin insertar nada todavía (bulkificación)
        List<VRT_Invoice__c> invoicesToInsert = new List<VRT_Invoice__c>();
        for (VRT_Rental__c rental : rentals)
        {
            invoicesToInsert.add(new VRT_Invoice__c(
                VRT_LKP_Rental__c = rental.Id,
                VRT_DIV_Amount__c = rental.VRT_DIV_TotalCost__c
            ));
        }

        try
        {
            // Un único DML para todas las facturas del lote
            insert invoicesToInsert;

            // Si llegamos aquí, el insert fue bien — registramos un log de Éxito por cada factura creada
            for (VRT_Invoice__c inv : invoicesToInsert)
            {
                logsToInsert.add(new VRT_ProcessLog__c(
                    VRT_LKP_Rental__c = inv.VRT_LKP_Rental__c,
                    VRT_TXT_Process__c = 'Generación de Factura',
                    VRT_SEL_Status__c = 'Éxito',
                    VRT_TXT_Detail__c = 'Factura generada correctamente: ' + inv.Id
                ));
            }
        }
        catch (Exception e)
        {
            // Si el insert falla, TODAS las facturas del lote se revierten juntas (todo-o-nada).
            // Por eso recorremos "rentals" (los datos de origen), no "invoicesToInsert" (que quedó sin Id real)
            for (VRT_Rental__c rental : rentals)
            {
                logsToInsert.add(new VRT_ProcessLog__c(
                    VRT_LKP_Rental__c = rental.Id,
                    VRT_TXT_Process__c = 'Generación de Factura',
                    VRT_SEL_Status__c = 'Error',
                    VRT_TXT_Detail__c = e.getMessage()
                ));
            }
        }
    }

    // Envía (o intenta enviar) un email por cada Alquiler, de forma independiente entre sí:
    // el fallo de uno no afecta a los demás ni a las Facturas ya creadas en el paso anterior
    private void sendEmailNotifications(List<VRT_Rental__c> rentals, List<VRT_ProcessLog__c> logsToInsert)
    {
        // try/catch DENTRO del bucle (no fuera) a propósito: si el email de un cliente falla,
        // el resto de clientes del lote deben seguir recibiendo el suyo con normalidad
        for (VRT_Rental__c rental : rentals)
        {
            try
            {
                // Si no hay email registrado, forzamos nuestra propia excepción para que caiga en el catch
                // y quede registrada como un Error de negocio claro, no un fallo técnico confuso
                if (String.isBlank(rental.VRT_LKP_Account__r.VRT_TXT_Email__c))
                    throw new VRT_InvoicingException('El cliente no tiene email registrado.');

                // Construcción y envío del email real
                Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                email.setToAddresses(new String[]{ rental.VRT_LKP_Account__r.VRT_TXT_Email__c });
                email.setSubject('Factura de tu alquiler');
                email.setPlainTextBody('Gracias por tu alquiler. Adjuntamos el resumen de tu factura.');
                Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ email });

                // Registramos la evidencia funcional de que el envío se intentó y funcionó
                logsToInsert.add(new VRT_ProcessLog__c(
                    VRT_LKP_Rental__c = rental.Id,
                    VRT_TXT_Process__c = 'Envío de Email',
                    VRT_SEL_Status__c = 'Éxito',
                    VRT_TXT_Detail__c = 'Email enviado a: ' + rental.VRT_LKP_Account__r.VRT_TXT_Email__c
                ));
            }
            catch (Exception e)
            {
                // Cualquier fallo (sin email, error de Messaging, lo que sea) queda registrado aquí,
                // sin interrumpir el procesamiento de los demás alquileres del bucle
                logsToInsert.add(new VRT_ProcessLog__c(
                    VRT_LKP_Rental__c = rental.Id,
                    VRT_TXT_Process__c = 'Envío de Email',
                    VRT_SEL_Status__c = 'Error',
                    VRT_TXT_Detail__c = e.getMessage()
                ));
            }
        }
    }
}