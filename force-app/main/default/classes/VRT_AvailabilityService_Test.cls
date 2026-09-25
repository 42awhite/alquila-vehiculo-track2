@isTest
private class VRT_AvailabilityService_Test
{
    @testSetup
    static void setup()
    {
        Account acc = new Account(Name = 'Cliente Test Disponibilidad');
        insert acc;

        VRT_Vehicle__c coche = new VRT_Vehicle__c(
            VRT_TXT_Brand__c = 'Seat',
            VRT_TXT_Model__c = 'Ibiza',
            VRT_SEL_VehicleType__c = 'Coche',
            VRT_TXT_LicensePlate__c = '9999ZZZ',
            VRT_SEL_Status__c = 'Listo',
            VRT_DAT_ManufacturedYear__c = Date.newInstance(2022, 1, 1),
            VRT_SEL_EnergyType__c = 'Gasolina',
            VRT_NUM_Passengers__c = 5,
            VRT_NUM_Mileage__c = 0,
            VRT_FLG_Available__c = true
        );
        insert coche;
    }

    // Positivo: fechas sin ningún conflicto -> se guarda con normalidad
    @isTest
    static void testSinConflicto()
    {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        VRT_Vehicle__c v = [SELECT Id FROM VRT_Vehicle__c LIMIT 1];

        VRT_Rental__c rental = new VRT_Rental__c(
            VRT_LKP_Account__c = acc.Id,
            VRT_LKP_Vehicle__c = v.Id,
            VRT_DAT_InitialDate__c = Date.newInstance(2027, 3, 10),
            VRT_DAT_FinalDate__c = Date.newInstance(2027, 3, 15),
            VRT_SEL_Status__c = 'Reservado'
        );

        Test.startTest();
        insert rental;
        Test.stopTest();

        System.assertNotEquals(null, rental.Id, 'Debe guardarse sin problema');
    }

    // Negativo: solapamiento real contra un alquiler ya existente en BD
    @isTest
    static void testSolapamientoConExistenteBloquea()
    {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        VRT_Vehicle__c v = [SELECT Id FROM VRT_Vehicle__c LIMIT 1];

        insert new VRT_Rental__c(
            VRT_LKP_Account__c = acc.Id,
            VRT_LKP_Vehicle__c = v.Id,
            VRT_DAT_InitialDate__c = Date.newInstance(2027, 4, 10),
            VRT_DAT_FinalDate__c = Date.newInstance(2027, 4, 15),
            VRT_SEL_Status__c = 'Reservado'
        );

        VRT_Rental__c conflictivo = new VRT_Rental__c(
            VRT_LKP_Account__c = acc.Id,
            VRT_LKP_Vehicle__c = v.Id,
            VRT_DAT_InitialDate__c = Date.newInstance(2027, 4, 12),
            VRT_DAT_FinalDate__c = Date.newInstance(2027, 4, 18),
            VRT_SEL_Status__c = 'Reservado'
        );

        Test.startTest();
        Database.SaveResult result = Database.insert(conflictivo, false);
        Test.stopTest();

        System.assertEquals(false, result.isSuccess(), 'Debe bloquear el solapamiento');
        System.assert(result.getErrors()[0].getMessage().contains('se solapan'),
            'El mensaje debe indicar solapamiento');
    }

    // Caso límite: un alquiler empieza justo cuando el otro termina -> permitido
    @isTest
    static void testCasoLimitePermitido()
    {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        VRT_Vehicle__c v = [SELECT Id FROM VRT_Vehicle__c LIMIT 1];

        insert new VRT_Rental__c(
            VRT_LKP_Account__c = acc.Id,
            VRT_LKP_Vehicle__c = v.Id,
            VRT_DAT_InitialDate__c = Date.newInstance(2027, 5, 10),
            VRT_DAT_FinalDate__c = Date.newInstance(2027, 5, 15),
            VRT_SEL_Status__c = 'Reservado'
        );

        VRT_Rental__c limite = new VRT_Rental__c(
            VRT_LKP_Account__c = acc.Id,
            VRT_LKP_Vehicle__c = v.Id,
            VRT_DAT_InitialDate__c = Date.newInstance(2027, 5, 15),
            VRT_DAT_FinalDate__c = Date.newInstance(2027, 5, 20),
            VRT_SEL_Status__c = 'Reservado'
        );

        Test.startTest();
        insert limite;
        Test.stopTest();

        System.assertNotEquals(null, limite.Id, 'El caso límite debe permitirse');
    }

    // Bulk: dos alquileres NUEVOS, mismo lote, mismo vehículo, solapados entre sí
    @isTest
    static void testSolapamientoDentroDelMismoLote()
    {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        VRT_Vehicle__c v = [SELECT Id FROM VRT_Vehicle__c LIMIT 1];

        VRT_Rental__c r1 = new VRT_Rental__c(
            VRT_LKP_Account__c = acc.Id,
            VRT_LKP_Vehicle__c = v.Id,
            VRT_DAT_InitialDate__c = Date.newInstance(2027, 6, 10),
            VRT_DAT_FinalDate__c = Date.newInstance(2027, 6, 15),
            VRT_SEL_Status__c = 'Reservado'
        );
        VRT_Rental__c r2 = new VRT_Rental__c(
            VRT_LKP_Account__c = acc.Id,
            VRT_LKP_Vehicle__c = v.Id,
            VRT_DAT_InitialDate__c = Date.newInstance(2027, 6, 12),
            VRT_DAT_FinalDate__c = Date.newInstance(2027, 6, 18),
            VRT_SEL_Status__c = 'Reservado'
        );

        Test.startTest();
        List<Database.SaveResult> results = Database.insert(new List<VRT_Rental__c>{ r1, r2 }, false);
        Test.stopTest();

        Integer fallidos = 0;
        for (Database.SaveResult res : results)
        {
            if (!res.isSuccess()) 
                fallidos++;
        }
        System.assertEquals(1, fallidos, 'Uno de los dos debe bloquearse por solapar con el otro del mismo lote');
    }
}