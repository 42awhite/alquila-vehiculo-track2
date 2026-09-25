@isTest
private class VRT_InvoicingQueueable_Test
{
    // Datos comunes a los 3 tests: un Cliente con email válido y un Vehículo listo
    @testSetup
    static void setup()
    {
        Account acc = new Account(Name = 'Cliente Test Facturacion', VRT_TXT_Email__c = 'cliente@test.com');
        insert acc;

        VRT_Vehicle__c v = new VRT_Vehicle__c(
            VRT_TXT_Brand__c = 'Renault',
            VRT_TXT_Model__c = 'Clio',
            VRT_SEL_VehicleType__c = 'Coche',
            VRT_TXT_LicensePlate__c = '2222BBB',
            VRT_SEL_Status__c = 'Listo',
            VRT_DAT_ManufacturedYear__c = Date.newInstance(2022, 1, 1),
            VRT_SEL_EnergyType__c = 'Gasolina',
            VRT_NUM_Passengers__c = 5,
            VRT_NUM_Mileage__c = 0,
            VRT_FLG_Available__c = true
        );
        insert v;
    }

    // Positivo: al pasar a Completado, el trigger encola el Queueable, que genera Factura + 2 Logs de Éxito
    @isTest
    static void testInvoiceGeneratedOnCompletion()
    {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        VRT_Vehicle__c v = [SELECT Id FROM VRT_Vehicle__c LIMIT 1];

        VRT_Rental__c rental = new VRT_Rental__c(
            VRT_LKP_Account__c = acc.Id,
            VRT_LKP_Vehicle__c = v.Id,
            VRT_DAT_InitialDate__c = Date.today().addDays(-10),
            VRT_DAT_FinalDate__c = Date.today().addDays(-5),
            VRT_SEL_Status__c = 'Reservado'
        );
        insert rental;

        // Test.startTest()/stopTest() aquí cumplen una función extra a la habitual:
        // fuerzan a que el Queueable (que normalmente se ejecutaría "más tarde", en otra transacción)
        // se ejecute de forma SÍNCRONA justo en el stopTest(), para poder comprobar su resultado a continuación
        Test.startTest();
        rental.VRT_SEL_Status__c = 'Completado';
        update rental;
        Test.stopTest();

        List<VRT_Invoice__c> invoices = [SELECT Id FROM VRT_Invoice__c WHERE VRT_LKP_Rental__c = :rental.Id];
        System.assertEquals(1, invoices.size(), 'Debe haberse creado exactamente una factura');

        List<VRT_ProcessLog__c> logs = [SELECT VRT_TXT_Process__c, VRT_SEL_Status__c FROM VRT_ProcessLog__c WHERE VRT_LKP_Rental__c = :rental.Id];
        System.assertEquals(2, logs.size(), 'Debe haber un log de Factura y otro de Email');
    }

    // Negativo: si ya existe una factura para el alquiler, no se debe crear una segunda
    @isTest
    static void testNoDuplicateInvoice()
    {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        VRT_Vehicle__c v = [SELECT Id FROM VRT_Vehicle__c LIMIT 1];

        // Insertado directamente como Completado: onAfterInsert NO encola el Queueable (solo onAfterUpdate lo hace),
        // así que este insert por sí solo no genera ninguna factura todavía
        VRT_Rental__c rental = new VRT_Rental__c(
            VRT_LKP_Account__c = acc.Id,
            VRT_LKP_Vehicle__c = v.Id,
            VRT_DAT_InitialDate__c = Date.today().addDays(-10),
            VRT_DAT_FinalDate__c = Date.today().addDays(-5),
            VRT_SEL_Status__c = 'Completado'
        );
        insert rental;

        // Creamos manualmente la factura "previa" que ya existiría en un caso real
        insert new VRT_Invoice__c(
            VRT_LKP_Rental__c = rental.Id,
            VRT_DIV_Amount__c = 100
        );

        // Llamamos al Queueable directamente (sin pasar por el trigger), simulando un segundo intento de facturación
        Test.startTest();
        System.enqueueJob(new VRT_InvoicingQueueable(new Set<Id>{ rental.Id }));
        Test.stopTest();

        List<VRT_Invoice__c> invoices = [SELECT Id FROM VRT_Invoice__c WHERE VRT_LKP_Rental__c = :rental.Id];
        System.assertEquals(1, invoices.size(), 'No debe haberse creado una segunda factura');
    }

    // Negativo controlado: cliente sin email -> la Factura se crea igual, pero el Log de Email queda en Error
    @isTest
    static void testEmailErrorLoggedButInvoiceStillCreated()
    {
        Account accSinEmail = new Account(Name = 'Cliente Sin Email'); // VRT_TXT_Email__c se deja vacío a propósito
        insert accSinEmail;
        VRT_Vehicle__c v = [SELECT Id FROM VRT_Vehicle__c LIMIT 1];

        VRT_Rental__c rental = new VRT_Rental__c(
            VRT_LKP_Account__c = accSinEmail.Id,
            VRT_LKP_Vehicle__c = v.Id,
            VRT_DAT_InitialDate__c = Date.today().addDays(-10),
            VRT_DAT_FinalDate__c = Date.today().addDays(-5),
            VRT_SEL_Status__c = 'Reservado'
        );
        insert rental;

        Test.startTest();
        rental.VRT_SEL_Status__c = 'Completado';
        update rental;
        Test.stopTest();

        List<VRT_Invoice__c> invoices = [SELECT Id FROM VRT_Invoice__c WHERE VRT_LKP_Rental__c = :rental.Id];
        System.assertEquals(1, invoices.size(), 'La factura debe crearse aunque el email falle después');

        VRT_ProcessLog__c emailLog = [
            SELECT VRT_SEL_Status__c FROM VRT_ProcessLog__c
            WHERE VRT_LKP_Rental__c = :rental.Id AND VRT_TXT_Process__c = 'Envío de Email'
            LIMIT 1
        ];
        System.assertEquals('Error', emailLog.VRT_SEL_Status__c, 'Debe quedar registrado el fallo de email sin tumbar la factura');
    }
}