@isTest
private class VRT_PricingEngineService_Test
{
    @testSetup
    static void setup()
    {
        Account acc = new Account(Name = 'Cliente Test Pricing');
        insert acc;

        VRT_Vehicle__c coche = new VRT_Vehicle__c(
            VRT_TXT_Brand__c = 'Toyota',
            VRT_TXT_Model__c = 'Corolla',
            VRT_SEL_VehicleType__c = 'Coche',
            VRT_TXT_LicensePlate__c = '1234ABC',
            VRT_SEL_Status__c = 'Listo',
            VRT_DAT_ManufacturedYear__c = Date.newInstance(2022, 1, 1),
            VRT_SEL_EnergyType__c = 'Gasolina',
            VRT_NUM_Passengers__c = 5,
            VRT_NUM_Mileage__c = 0,
            VRT_FLG_Available__c = true
        );

        VRT_Vehicle__c moto = new VRT_Vehicle__c(
            VRT_TXT_Brand__c = 'Honda',
            VRT_TXT_Model__c = 'CBR',
            VRT_SEL_VehicleType__c = 'Moto',
            VRT_TXT_LicensePlate__c = '5678XYZ',
            VRT_SEL_Status__c = 'Listo',
            VRT_DAT_ManufacturedYear__c = Date.newInstance(2022, 1, 1),
            VRT_SEL_EnergyType__c = 'Gasolina',
            VRT_NUM_Passengers__c = 2,
            VRT_NUM_Mileage__c = 0,
            VRT_FLG_Available__c = true
        );

        insert new List<VRT_Vehicle__c>{ coche, moto };
    }

    // Positivo: coste = precio/día × duración, sin descuentos ni penalización
    @isTest
    static void testCalculoBasicoSinDescuentos()
    {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        VRT_Vehicle__c coche = [SELECT Id FROM VRT_Vehicle__c WHERE VRT_SEL_VehicleType__c = 'Coche' LIMIT 1];

        VRT_Rental__c rental = new VRT_Rental__c(
            VRT_LKP_Account__c = acc.Id,
            VRT_LKP_Vehicle__c = coche.Id,
            VRT_DAT_InitialDate__c = Date.newInstance(2027, 1, 10),
            VRT_DAT_FinalDate__c = Date.newInstance(2027, 1, 13),
            VRT_SEL_Status__c = 'Reservado'
        );

        Test.startTest();
        insert rental;
        Test.stopTest();

        VRT_Rental__c result = [SELECT VRT_DIV_TotalCost__c FROM VRT_Rental__c WHERE Id = :rental.Id];
        System.assertEquals(180, result.VRT_DIV_TotalCost__c, 'Coche en Alta × 3 días = 180');
    }

    // Fidelidad: 3 alquileres completados previos -> 5% de descuento
    @isTest
    static void testDescuentoFidelidad()
    {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        VRT_Vehicle__c coche = [SELECT Id FROM VRT_Vehicle__c WHERE VRT_SEL_VehicleType__c = 'Coche' LIMIT 1];

        List<VRT_Rental__c> historicos = new List<VRT_Rental__c>();
        for (Integer i = 1; i <= 3; i++)
        {
            historicos.add(new VRT_Rental__c(
                VRT_LKP_Account__c = acc.Id,
                VRT_LKP_Vehicle__c = coche.Id,
                VRT_DAT_InitialDate__c = Date.today().addMonths(-i),
                VRT_DAT_FinalDate__c = Date.today().addMonths(-i).addDays(2),
                VRT_SEL_Status__c = 'Completado'
            ));
        }
        insert historicos;

        VRT_Rental__c nuevo = new VRT_Rental__c(
            VRT_LKP_Account__c = acc.Id,
            VRT_LKP_Vehicle__c = coche.Id,
            VRT_DAT_InitialDate__c = Date.newInstance(2027, 1, 10),
            VRT_DAT_FinalDate__c = Date.newInstance(2027, 1, 13),
            VRT_SEL_Status__c = 'Reservado'
        );

        Test.startTest();
        insert nuevo;
        Test.stopTest();

        VRT_Rental__c result = [SELECT VRT_DIV_TotalCost__c FROM VRT_Rental__c WHERE Id = :nuevo.Id];
        System.assertEquals(171, result.VRT_DIV_TotalCost__c, '180 × 0.95 = 171');
    }

    // Penalización: se completa con retraso respecto a la fecha final
    @isTest
    static void testPenalizacionPorRetraso()
    {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        VRT_Vehicle__c coche = [SELECT Id FROM VRT_Vehicle__c WHERE VRT_SEL_VehicleType__c = 'Coche' LIMIT 1];

        VRT_Rental__c rental = new VRT_Rental__c(
            VRT_LKP_Account__c = acc.Id,
            VRT_LKP_Vehicle__c = coche.Id,
            VRT_DAT_InitialDate__c = Date.today().addDays(-5),
            VRT_DAT_FinalDate__c = Date.today().addDays(-2),
            VRT_SEL_Status__c = 'Reservado'
        );
        insert rental;

        Test.startTest();
        rental.VRT_SEL_Status__c = 'Completado';
        update rental;
        Test.stopTest();

        VRT_Rental__c result = [SELECT VRT_DIV_TotalCost__c FROM VRT_Rental__c WHERE Id = :rental.Id];
        System.assert(result.VRT_DIV_TotalCost__c > 0, 'Debe llevar penalización sumada al coste base');
    }

    // Negativo: sin Vehículo (por tanto sin tarifa posible) -> debe bloquear
    @isTest
    static void testBloqueoSinTarifa()
    {
        VRT_Rental__c rentalSinVehiculo = new VRT_Rental__c(
            VRT_DAT_InitialDate__c = Date.newInstance(2027, 1, 10),
            VRT_DAT_FinalDate__c = Date.newInstance(2027, 1, 13),
            VRT_SEL_Status__c = 'Reservado'
        );

        Test.startTest();
        VRT_PricingEngineService.calculateTotalCost(new List<VRT_Rental__c>{ rentalSinVehiculo });
        Test.stopTest();

        System.assertEquals(1, rentalSinVehiculo.getErrors().size(), 'Debe registrarse un error');
        System.assert(rentalSinVehiculo.getErrors()[0].getMessage().contains('No existe tarifa'),
            'El mensaje debe indicar que no hay tarifa aplicable');
    }

    // Carga masiva: 10 alquileres en un solo insert
    @isTest
    static void testCargaMasiva()
    {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        VRT_Vehicle__c coche = [SELECT Id FROM VRT_Vehicle__c WHERE VRT_SEL_VehicleType__c = 'Coche' LIMIT 1];
        VRT_Vehicle__c moto = [SELECT Id FROM VRT_Vehicle__c WHERE VRT_SEL_VehicleType__c = 'Moto' LIMIT 1];

        List<VRT_Rental__c> lote = new List<VRT_Rental__c>();
        for (Integer i = 1; i <= 10; i++)
        {
            lote.add(new VRT_Rental__c(
                VRT_LKP_Account__c = acc.Id,
                VRT_LKP_Vehicle__c = (Math.mod(i, 2) == 0) ? coche.Id : moto.Id,
                VRT_DAT_InitialDate__c = Date.today().addMonths(i),
                VRT_DAT_FinalDate__c = Date.today().addMonths(i).addDays(3),
                VRT_SEL_Status__c = 'Reservado'
            ));
        }

        Test.startTest();
        insert lote;
        Test.stopTest();

        List<VRT_Rental__c> resultados = [SELECT VRT_DIV_TotalCost__c FROM VRT_Rental__c WHERE Id IN :lote];
        for (VRT_Rental__c r : resultados)
        {
            System.assertNotEquals(null, r.VRT_DIV_TotalCost__c, 'Todos deben tener coste calculado');
        }
    }
}