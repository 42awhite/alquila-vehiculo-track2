@isTest
public class VRT_CLS_CheckVehicleRevision_Test {
    // Método de prueba para VRT_CLS_CheckVehicleRevision
    @isTest static void testCheckVehicleRevision() {
        // Crea algunos registros de vehículos para probar
        List<VRT_Vehicle__c> vehicles = new List<VRT_Vehicle__c>();
        vehicles.add(new VRT_Vehicle__c(VRT_TXT_ExternalId__c = 'TestVeh'+0, 
                                        VRT_TXT_LicensePlate__c = 'TST000'+0,
                                        VRT_TXT_Brand__c = 'Opel', 
                                        VRT_SEL_VehicleType__c = 'Coche', 
                                        VRT_SEL_Status__c = 'Listo',  
                                        VRT_SEL_EnergyType__c = 'Diesel', 
                                        VRT_NUM_Passengers__c = 5,
                                        VRT_DAT_ManufacturedYear__c = System.today().addYears(-5)
                                       ));
        vehicles.add(new VRT_Vehicle__c(VRT_TXT_ExternalId__c = 'TestVeh'+1, 
                                        VRT_TXT_LicensePlate__c = 'TST000'+1,
                                        VRT_TXT_Brand__c = 'Opel', 
                                        VRT_SEL_VehicleType__c = 'Moto', 
                                        VRT_SEL_Status__c = 'Listo',  
                                        VRT_SEL_EnergyType__c = 'Diesel', 
                                        VRT_NUM_Passengers__c = 5,
                                        VRT_DAT_ManufacturedYear__c = System.today().addYears(-4)
                                       ));
        insert vehicles;
        
        // Ejecuta el batch
        Test.startTest();
        VRT_CLS_CheckVehicleRevision batch = new VRT_CLS_CheckVehicleRevision();
        Database.executeBatch(batch);
        Test.stopTest();
        
        // Verifica que los vehículos sean marcados correctamente para inspección
        List<VRT_Vehicle__c> updatedVehicles = [SELECT Id, VRT_FLG_NeedsInspection__c FROM VRT_Vehicle__c];
        System.assertEquals(2, updatedVehicles.size());
        System.assertEquals(true, updatedVehicles[0].VRT_FLG_NeedsInspection__c);
        System.assertEquals(true, updatedVehicles[1].VRT_FLG_NeedsInspection__c);
    }
}