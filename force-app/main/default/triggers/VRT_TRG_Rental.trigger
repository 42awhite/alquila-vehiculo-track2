/**
 * @author      AMADRIDN (NTT Data)
 * @since       04/04/2024
 * @desc        trigger for object VRT_TRG_Rental
 * @history     04/04/2024 - AMADRIDN - Created class
 *              08/04/2024 - AMADRIDN - Added comments
 */

trigger VRT_TRG_Rental on VRT_Rental__c (after insert, after update, before insert, before update) 
{
    VRT_TRG_RentalHandler rentalHandler = new VRT_TRG_RentalHandler();
    if (trigger.isAfter) 
    {
        if (trigger.isInsert) 
            rentalHandler.onAfterInsert(trigger.new);
        if (trigger.isUpdate)
            rentalHandler.onAfterUpdate(trigger.oldMap, trigger.newMap);
    }
    if (trigger.isBefore) 
    {
        if (trigger.isInsert)
            rentalHandler.onBeforeInsert(trigger.new);
        
        if (trigger.isUpdate)
            rentalHandler.onBeforeUpdate(trigger.oldMap, trigger.newMap);
    }
}

