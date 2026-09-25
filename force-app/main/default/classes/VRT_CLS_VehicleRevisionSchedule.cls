public class VRT_CLS_VehicleRevisionSchedule implements Schedulable {
    public void execute(SchedulableContext ctx) {
        VRT_CLS_CheckVehicleRevision batch = new VRT_CLS_CheckVehicleRevision();
        Database.executebatch(batch, 200);
    }
}