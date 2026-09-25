/**
 *  @author		AMADRIDN (NTT Data)
 * @since		04/04/2024
 * @desc		Clase para comprobar revisión ITV en vehículos
 * @history		18/04/2024 - AMADRIDN - Created class
 */
public class VRT_CLS_CheckVehicleRevision implements Database.Batchable<sObject> {
    
    public VRT_CLS_CheckVehicleRevision() {}
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator('SELECT Id, VRT_DAT_ManufacturedYear__c, VRT_FLG_NeedsInspection__c, VRT_SEL_VehicleType__c FROM VRT_Vehicle__c WHERE VRT_FLG_NeedsInspection__c = false');
    }
    
    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        // Obtenemos el año actual
        Integer thisYear = Date.today().year();
        
        
        for(SObject s : scope) {
            VRT_Vehicle__c veh = (VRT_Vehicle__c) s;
            // Obtenemos los años transcurridos desde que se fabricó
            Integer yearsPassed = thisYear -  veh.VRT_DAT_ManufacturedYear__c.year();
            // Si es un coche, comprueba que hayan pasado 4 años
            if(veh.VRT_SEL_VehicleType__c == 'Coche' && yearsPassed >= 4) {
                veh.VRT_FLG_NeedsInspection__c = true;
            }
            // Si es una moto, comprueba que hayan pasado 3 años
            else if(veh.VRT_SEL_VehicleType__c == 'Moto' && yearsPassed >= 3) {
                veh.VRT_FLG_NeedsInspection__c = true;
            } 
        }      
        update scope;
    }
    
    public void finish(Database.BatchableContext bc) {
        
    }
    
}