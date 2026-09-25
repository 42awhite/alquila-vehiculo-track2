/**
 * @author		AMADRIDN (NTT Data)
 * @since		04/04/2024
 * @desc		Handler class for trigger VRT_TRG_Rental
 * @history		04/04/2024 - AMADRIDN - Created class
 * 				08/04/2024 - AMADRIDN - Added comments
 * 				12/04/2024 - AMADRIDN - Added onAfterUpdate
 */
public class VRT_TRG_RentalHandler 
{
    /**
     * @desc	After Insert Handler
     * @param	triggerNew: list of rentals inserted
     */
    public void onAfterInsert(List<VRT_Rental__c> triggerNew)
    {
        VRT_TRG_RentalHandlerHelper.updateConditionVehicle(triggerNew);
    }
    
    /**
     * @desc	After Update Handler
     * @param	oldMap: map with rentals in old state 
     * @param	newMap: map with rentals in new state 
     */
    public void onAfterUpdate(Map<Id, VRT_Rental__c> oldMap, Map<Id, VRT_Rental__c> newMap)
    {
        VRT_TRG_RentalHandlerHelper.updateVehicleRentalCompleted(oldMap, newMap);

        Set<Id> completedRentalIds = new Set<Id>();
        for (Id rentalId : newMap.keySet())
        {
            if (oldMap.get(rentalId).VRT_SEL_Status__c != 'Completado' && newMap.get(rentalId).VRT_SEL_Status__c == 'Completado')
                completedRentalIds.add(rentalId);
        }
        if (!completedRentalIds.isEmpty())
            System.enqueueJob(new VRT_InvoicingQueueable(completedRentalIds));
    }

    /**
     * @desc	Before Insert Handler
     * @param	triggerNew: list of rentals to be inserted
     */
    public void onBeforeInsert(List<VRT_Rental__c> triggerNew) 
    {
        VRT_PricingEngineService.calculateTotalCost(triggerNew);
        VRT_AvailabilityService.checkOverlaps(triggerNew);
    }

    /**
     * @desc	Before Update Handler
     * @param	oldMap: map with rentals in old state 
     * @param	newMap: map with rentals in new state 
     */
    public void onBeforeUpdate(Map<Id, VRT_Rental__c> oldMap, Map<Id, VRT_Rental__c> newMap)
    {
        VRT_PricingEngineService.calculateTotalCost(newMap.values());
        VRT_AvailabilityService.checkOverlaps(newMap.values());
    }
}