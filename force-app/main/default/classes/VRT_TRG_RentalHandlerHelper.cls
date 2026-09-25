/**
 * @author		AMADRIDN (NTT Data)
 * @since		04/04/2024
 * @desc		Helper class for trigger VRT_TRG_Rental
 * @history		04/04/2024 - AMADRIDN - Created class
 * 				08/04/2024 - AMADRIDN - Added comments and fixed calculateCondition 
 */
public class VRT_TRG_RentalHandlerHelper {
    /**
     * @desc	Update the vehicle condition based on number of uses
     * @param	triggerNew: list of vehicles inserted
     */
    public static void updateConditionVehicle(List<VRT_Rental__c> triggerNew) {
        Set<Id> vehicleIds = new Set<Id>(); 
        for(VRT_Rental__c rental : triggerNew){
            // Guardamos los ids de los alquileres que tengan el vehículo relleno
            if(rental.VRT_LKP_Vehicle__c != null) {
                vehicleIds.add(rental.VRT_LKP_Vehicle__c);
            }
        }
        
        // Obtenemos los vehículos y añadimos un Uso y calculamos la condición
        List<VRT_Vehicle__c> vehicles = [SELECT Id,
                                          		 VRT_NUM_Usage__c,
                                            	 VRT_SEL_Condition__c
                                          FROM VRT_Vehicle__c
                                          WHERE Id IN :vehicleIds]; 
        if(vehicles != null && vehicles.size() > 0) {
            for(VRT_Vehicle__c vehicle : vehicles) {
                vehicle.VRT_NUM_Usage__c = vehicle.VRT_NUM_Usage__c != null? vehicle.VRT_NUM_Usage__c + 1 : 0;
                vehicle.VRT_SEL_Condition__c = calculateCondition(vehicle.VRT_NUM_Usage__c.intValue());
            }
            update vehicles;
        }
    }
    
    /**
     * @desc	Update the vehicle mileage based on rental duration
     * @param	oldMap: map with rentals in old state 
     * @param	newMap: map with rentals in new state 
     */
    public static void updateVehicleRentalCompleted(Map<Id, VRT_Rental__c> oldMap, Map<Id, VRT_Rental__c> newMap) {
		Map<Id, VRT_Rental__c> completedVehRentals = new Map<Id, VRT_Rental__c>();
        
        for (Id rentalId : newMap.keySet()) {
            VRT_Rental__c oldRental = oldMap.get(rentalId);
            VRT_Rental__c newRental = newMap.get(rentalId);
            
            // Cambio de estado de En curso a Completado
            if(oldRental.VRT_SEL_Status__c == 'En curso' && newRental.VRT_SEL_Status__c == 'Completado' && newRental.VRT_LKP_Vehicle__c != null) {
                completedVehRentals.put(newRental.VRT_LKP_Vehicle__c, newRental);
            }
        }
        
        // Si algún alquiler se completó, actualizamos el kilometraje del vehículo asociado basado en los días que duró el alquiler x 200km
        if(completedVehRentals.keyset().size() > 0) {
            List<VRT_Vehicle__c> vehicles = [SELECT Id,
                                                    VRT_NUM_Mileage__c
                                             FROM VRT_Vehicle__c
                                             WHERE Id IN :completedVehRentals.keyset()];
            if(vehicles != null && vehicles.size() > 0) {
                for(VRT_Vehicle__c vehicle : vehicles) {
                    vehicle.VRT_NUM_Mileage__c = vehicle.VRT_NUM_Mileage__c + (completedVehRentals.get(vehicle.Id).VRT_FOR_Duration__c * 200);
                }
                
                update vehicles;
            }
        }
    }

    /**
     * @desc	Calculate vehicle condition string based of number of uses
     * @param	numberOfUses: number of vehicle uses
     * @return	conditionResult: string with resulted condition
     */
    public static String calculateCondition(Integer numberOfUses) {
        String conditionResult = 'Deplorable';
        
        if(numberOfUses <= 50) {
            conditionResult = 'Recién fabricado';
        } else if(numberOfUses <= 200) {
            conditionResult = 'Casi nuevo';
        } else if(numberOfUses <= 500) {
            conditionResult = 'Algo desgastado';
        } else if(numberOfUses <= 1000) {
            conditionResult = 'Bastante desgastado';
        } else if (numberOfUses > 1000) {
            conditionResult = 'Deplorable';
        }
        
        return conditionResult;
    }
}