import { LightningElement, api, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getActiveRentals from '@salesforce/apex/VRT_RentalConsoleController.getActiveRentals';
import simulatePrice from '@salesforce/apex/VRT_RentalConsoleController.simulatePrice';
import createRental from '@salesforce/apex/VRT_RentalConsoleController.createRental';

// sortable: true en cada columna es lo que activa las opciones reales de "Sort Ascending/Descending" en el menú
const COLUMNS = [
    { label: 'Vehículo', fieldName: 'vehicleName', sortable: true },
    { label: 'Fecha Inicio', fieldName: 'VRT_DAT_InitialDate__c', type: 'date', sortable: true },
    { label: 'Fecha Final', fieldName: 'VRT_DAT_FinalDate__c', type: 'date', sortable: true },
    { label: 'Estado', fieldName: 'VRT_SEL_Status__c', sortable: true },
    { label: 'Coste Total', fieldName: 'VRT_DIV_TotalCost__c', type: 'currency', sortable: true }
];

export default class VrtRentalConsole extends LightningElement {

    @api recordId;
    columns = COLUMNS;
    rentals = [];
    error;
    wiredRentalsResult;

    // BLOQUE NUEVO: estado del filtro por Estado
    statusFilter = 'All';
    statusOptions = [
        { label: 'Todos', value: 'All' },
        { label: 'Reservado', value: 'Reservado' },
        { label: 'En curso', value: 'En curso' }
    ];

    // BLOQUE NUEVO: estado del ordenamiento actual (para que la tabla muestre la flechita en la columna correcta)
    sortedBy;
    sortedDirection = 'asc';

    isModalOpen = false;
    vehicleId;
    startDate;
    endDate;
    simulatedPrice;
    isSimulating = false;
    isSaving = false;

    @wire(getActiveRentals, { accountId: '$recordId' })
    wiredRentals(result) {
        this.wiredRentalsResult = result;
        const { data, error } = result;
        if (data) {
            this.rentals = data.map(rental => ({
                ...rental,
                vehicleName: rental.VRT_LKP_Vehicle__r
                    ? rental.VRT_LKP_Vehicle__r.VRT_TXT_Brand__c + ' ' + rental.VRT_LKP_Vehicle__r.VRT_TXT_Model__c
                    : ''
            }));
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.rentals = [];
        }
    }

    // BLOQUE NUEVO: filtro
    // "getter" calculado: cada vez que rentals o statusFilter cambian, esta lista se recalcula sola,
    // y es la que le pasamos a la tabla en vez de "rentals" directamente
    get filteredRentals() {
        if (this.statusFilter === 'All') {
            return this.rentals;
        }
        return this.rentals.filter(rental => rental.VRT_SEL_Status__c === this.statusFilter);
    }

    handleStatusFilterChange(event) {
        this.statusFilter = event.detail.value;
    }

    // BLOQUE NUEVO: ordenamiento
    // lightning-datatable NO ordena los datos por sí sola — solo avisa (evento onsort) de qué columna
    // y dirección quiere el usuario; el propio componente es responsable de reordenar el array.
    handleSort(event) {
        this.sortedBy = event.detail.fieldName;
        this.sortedDirection = event.detail.sortDirection;

        const reverse = this.sortedDirection === 'asc' ? 1 : -1;
        this.rentals = [...this.rentals].sort((a, b) => {
            const valA = a[this.sortedBy] ?? '';
            const valB = b[this.sortedBy] ?? '';
            return reverse * ((valA > valB) - (valA < valB));
        });
    }

    openModal() {
        this.isModalOpen = true;
        this.vehicleId = undefined;
        this.startDate = undefined;
        this.endDate = undefined;
        this.simulatedPrice = undefined;
    }

    closeModal() {
        this.isModalOpen = false;
    }

    handleVehicleChange(event) {
        this.vehicleId = event.detail.recordId;
        this.simulatedPrice = undefined;
    }

    handleStartDateChange(event) {
        this.startDate = event.target.value;
        this.simulatedPrice = undefined;
    }

    handleEndDateChange(event) {
        this.endDate = event.target.value;
        this.simulatedPrice = undefined;
    }

    handleSimulate() {
        this.isSimulating = true;
        simulatePrice({
            vehicleId: this.vehicleId,
            accountId: this.recordId,
            startDate: this.startDate,
            endDate: this.endDate
        })
            .then(result => {
                this.simulatedPrice = result;
            })
            .catch(error => {
                this.showError(error);
            })
            .finally(() => {
                this.isSimulating = false;
            });
    }

    handleCreate() {
        this.isSaving = true;
        createRental({
            vehicleId: this.vehicleId,
            accountId: this.recordId,
            startDate: this.startDate,
            endDate: this.endDate
        })
            .then(() => {
                this.showToast('Éxito', 'Alquiler creado correctamente', 'success');
                this.closeModal();
                return refreshApex(this.wiredRentalsResult);
            })
            .catch(error => {
                this.showError(error);
            })
            .finally(() => {
                this.isSaving = false;
            });
    }

    showError(error) {
        const message = (error && error.body && error.body.message) || 'Ha ocurrido un error inesperado.';
        this.showToast('Error', message, 'error');
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}