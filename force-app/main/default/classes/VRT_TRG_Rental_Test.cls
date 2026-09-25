/**
 * @author		AMADRIDN (NTT Data)
 * @since		04/04/2024
 * @desc		Test class for trigger VRT_TRG_Alquiler
 * @history		04/04/2024 - AMADRIDN - Created class
 * 				08/04/2024 - AMADRIDN - Added comments
 */
@isTest
public class VRT_TRG_Rental_Test {
    
    @testSetup static void setup() {
 		// Create common test accounts
        List<Account> testAccts = new List<Account>();
        for(Integer i=0;i<2;i++) {
            testAccts.add(new Account(Name = 'TestAcct'+i));
        }
        insert testAccts;  
        
        // Create common test vehicles
        List<VRT_Vehicle__c> testVehics = new List<VRT_Vehicle__c>();
        for(Integer i=0;i<5;i++) {
            VRT_Vehicle__c veh = new VRT_Vehicle__c(VRT_TXT_ExternalId__c = 'TestVeh'+i, 
                                                      VRT_TXT_LicensePlate__c = 'TST000'+i,
                                                      VRT_TXT_Brand__c = 'Opel', 
                                                      VRT_SEL_VehicleType__c = 'Coche', 
                                                      VRT_SEL_Status__c = 'Listo',  
                                                      VRT_SEL_EnergyType__c = 'Diesel', 
                                                      VRT_NUM_Passengers__c = 5,
                                                      VRT_FLG_Available__c = true
                                                     );
            // Update nº de usos
            switch on i {
                when 0 {		
                    veh.VRT_NUM_Usage__c = 1;
                    veh.VRT_NUM_Mileage__c = 0;
                }
                when 1 {
                    veh.VRT_NUM_Usage__c = 51;
                    veh.VRT_NUM_Mileage__c = 200;
                }
                when 2 {
                    veh.VRT_NUM_Usage__c = 201;
                    veh.VRT_NUM_Mileage__c = 600;
                }
                when 3 {
                    veh.VRT_NUM_Usage__c = 501;
                    veh.VRT_NUM_Mileage__c = 800;
                }
                when 4 {
                    veh.VRT_NUM_Usage__c = 1001;
                    veh.VRT_NUM_Mileage__c = 1000;
                }
            }
			testVehics.add(veh);
        }
        insert testVehics; 
	}
    
	@isTest static void testUpdateConditionVehicleRecienFabricado() {
        // Create a rental
		VRT_Rental__c rental = createRentalTest(0);
        
        Test.startTest();
		insert rental;
        Test.stopTest();
        
        // Get updated Vehicule
        VRT_Vehicle__c vehUpdated = [SELECT Id, VRT_SEL_Condition__c FROM VRT_Vehicle__c WHERE VRT_TXT_ExternalId__c = 'TestVeh0' LIMIT 1];
        System.assertEquals('Recién fabricado', vehUpdated.VRT_SEL_Condition__c);
    }
    
    @isTest static void testUpdateConditionVehicleCasiNuevo() {
        // Create a rental
        VRT_Rental__c rental = createRentalTest(1);
        
        Test.startTest();
		insert rental;
        Test.stopTest();
        
        // Get updated Vehicule
        VRT_Vehicle__c vehUpdated = [SELECT Id, VRT_SEL_Condition__c FROM VRT_Vehicle__c WHERE VRT_TXT_ExternalId__c = 'TestVeh1' LIMIT 1];
        System.assertEquals('Casi nuevo', vehUpdated.VRT_SEL_Condition__c);
    }
    
    @isTest static void testUpdateConditionVehicleAlgoDesgastado() {
        // Create a rental
        VRT_Rental__c rental = createRentalTest(2);
        
        Test.startTest();
		insert rental;
        Test.stopTest();
        
        // Get updated Vehicule
        VRT_Vehicle__c vehUpdated = [SELECT Id, VRT_SEL_Condition__c FROM VRT_Vehicle__c WHERE VRT_TXT_ExternalId__c = 'TestVeh2' LIMIT 1];
        System.assertEquals('Algo desgastado', vehUpdated.VRT_SEL_Condition__c);
    }
    
    @isTest static void testUpdateConditionVehicleBastanteDesgastado() {
        // Create a rental
        VRT_Rental__c rental = createRentalTest(3);
        
        Test.startTest();
		insert rental;
        Test.stopTest();
        
        // Get updated Vehicule
        VRT_Vehicle__c vehUpdated = [SELECT Id, VRT_SEL_Condition__c FROM VRT_Vehicle__c WHERE VRT_TXT_ExternalId__c = 'TestVeh3' LIMIT 1];
        System.assertEquals('Bastante desgastado', vehUpdated.VRT_SEL_Condition__c);
    }
    
    @isTest static void testUpdateConditionVehicleDeplorable() {
        // Create a rental
        VRT_Rental__c rental = createRentalTest(4);
        
        Test.startTest();
		insert rental;
        Test.stopTest();
        
        // Get updated Vehicule
        VRT_Vehicle__c vehUpdated = [SELECT Id, VRT_SEL_Condition__c FROM VRT_Vehicle__c WHERE VRT_TXT_ExternalId__c = 'TestVeh4' LIMIT 1];
        System.assertEquals('Deplorable', vehUpdated.VRT_SEL_Condition__c);
    }
    
    @isTest static void testUpdateVehicleRentalCompleted() {
        // Create a rental
        VRT_Rental__c rental = createRentalTest(0);
        insert rental;
        
        Test.startTest();
		rental.VRT_SEL_Status__c = 'Completado';
        update rental;
        Test.stopTest();
        
        // Get updated Vehicule
        VRT_Vehicle__c vehUpdated = [SELECT Id, VRT_NUM_Mileage__c FROM VRT_Vehicle__c WHERE VRT_TXT_ExternalId__c = 'TestVeh0' LIMIT 1];
        System.assertEquals(600, vehUpdated.VRT_NUM_Mileage__c);
    }
    
    private static VRT_Rental__c createRentalTest(Integer vehCounter) {
        // Get the first test account and vehicle by using a SOQL query
        Account acc = [SELECT Id FROM Account WHERE Name = 'TestAcct0' LIMIT 1];
        String vehIdExt = 'TestVeh' + vehCounter;
        VRT_Vehicle__c veh = [SELECT Id FROM VRT_Vehicle__c WHERE VRT_TXT_ExternalId__c = :vehIdExt LIMIT 1];
        VRT_Rental__c rentalResult = new VRT_Rental__c();
        rentalResult.VRT_LKP_Account__c = acc.Id;
        rentalResult.VRT_LKP_Vehicle__c = veh.Id;
        rentalResult.VRT_DAT_InitialDate__c = Date.Today();
        rentalResult.VRT_DAT_FinalDate__c = Date.Today()+3;
        rentalResult.VRT_SEL_Status__c = 'En curso';
        return rentalResult;
    }
}