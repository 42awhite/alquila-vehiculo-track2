@isTest
public class VRT_CLS_VehicleRevisionSchedule_Test {
    // Método de prueba para VRT_CLS_VehicleRevisionSchedule
    @isTest
    static void testVehicleRevisionSchedule() {
        // Inicia la tarea programada
        Test.startTest();
        VRT_CLS_VehicleRevisionSchedule scheduledJob = new VRT_CLS_VehicleRevisionSchedule();
        scheduledJob.execute(null);
        Test.stopTest();
    }
}