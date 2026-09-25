@isTest
private class VRT_VehicleSearchController_Test
{
    // Creamos 2 vehículos con datos distintos para poder comprobar que la búsqueda filtra bien
    @testSetup
    static void setup()
    {
        List<VRT_Vehicle__c> vehicles = new List<VRT_Vehicle__c>();

        vehicles.add(new VRT_Vehicle__c(
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
        ));

        vehicles.add(new VRT_Vehicle__c(
            VRT_TXT_Brand__c = 'Yamaha',
            VRT_TXT_Model__c = 'MT-07',
            VRT_SEL_VehicleType__c = 'Moto',
            VRT_TXT_LicensePlate__c = '9999XYZ',
            VRT_SEL_Status__c = 'Listo',
            VRT_DAT_ManufacturedYear__c = Date.newInstance(2022, 1, 1),
            VRT_SEL_EnergyType__c = 'Gasolina',
            VRT_NUM_Passengers__c = 2,
            VRT_NUM_Mileage__c = 0,
            VRT_FLG_Available__c = true
        ));

        insert vehicles;
    }

    // Positivo: buscar la marca completa encuentra el vehículo correcto
    @isTest
    static void testSearchByFullBrand()
    {
        Test.startTest();
        List<VRT_Vehicle__c> results = VRT_VehicleSearchController.searchVehicles('Toyota');
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Debe encontrar exactamente el vehículo Toyota');
    }

    // Texto parcial: buscar solo una parte del modelo también debe encontrarlo
    @isTest
    static void testSearchByPartialModel()
    {
        Test.startTest();
        List<VRT_Vehicle__c> results = VRT_VehicleSearchController.searchVehicles('roll');
        Test.stopTest();

        System.assertEquals(1, results.size(), '"roll" debe encontrar "Corolla" aunque no sea la palabra completa');
    }

    // Texto demasiado corto: no debe lanzar error, solo devolver vacío
    @isTest
    static void testSearchTooShortReturnsEmpty()
    {
        Test.startTest();
        List<VRT_Vehicle__c> results = VRT_VehicleSearchController.searchVehicles('a');
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Con menos de 2 caracteres no debe buscar nada');
    }

    // Sin coincidencias: texto válido pero que no existe en ningún vehículo
    @isTest
    static void testSearchNoMatches()
    {
        Test.startTest();
        List<VRT_Vehicle__c> results = VRT_VehicleSearchController.searchVehicles('Ferrari');
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Un texto que no coincide con nada debe devolver lista vacía');
    }
}