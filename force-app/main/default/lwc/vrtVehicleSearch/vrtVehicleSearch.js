import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import searchVehicles from '@salesforce/apex/VRT_VehicleSearchController.searchVehicles';

const DEBOUNCE_DELAY = 300; // milisegundos de espera tras la última tecla

const COLUMNS = [
    { label: 'Matrícula', fieldName: 'VRT_TXT_LicensePlate__c' },
    { label: 'Marca', fieldName: 'VRT_TXT_Brand__c' },
    { label: 'Modelo', fieldName: 'VRT_TXT_Model__c' },
    { label: 'Estado', fieldName: 'VRT_SEL_Status__c' },
    {
        type: 'action',
        typeAttributes: { rowActions: [{ label: 'Ver Ficha', name: 'view' }] }
    }
];

// NavigationMixin permite que un LWC navegue a otras páginas de Salesforce (aquí, a la ficha del vehículo)
export default class VrtVehicleSearch extends NavigationMixin(LightningElement)
{
    columns = COLUMNS;
    results = [];
    hasSearched = false;
    delayTimeout; // aquí guardamos el "ticket" del temporizador activo, para poder cancelarlo

    // Se dispara cada vez que el usuario teclea en el cuadro de búsqueda
    handleSearchChange(event)
    {
        const searchTerm = event.target.value;

        // Si ya había un temporizador esperando, lo cancelamos — el usuario sigue escribiendo
        clearTimeout(this.delayTimeout);

        // Creamos un temporizador nuevo: solo si pasan 300ms SIN que esta función se vuelva a llamar,
        // se ejecutará la búsqueda real
        this.delayTimeout = setTimeout(() => {
            this.performSearch(searchTerm);
        }, DEBOUNCE_DELAY);
    }

    // La búsqueda real, llamada solo cuando el usuario deja de escribir un momento
    performSearch(searchTerm)
    {
        if (!searchTerm || searchTerm.length < 2)
        {
            this.results = [];
            this.hasSearched = false;
            return;
        }

        searchVehicles({ searchTerm })
            .then(data => {
                this.results = data;
                this.hasSearched = true;
            })
            .catch(error => {
                this.results = [];
                this.hasSearched = true;
            });
    }

    // Se dispara al hacer clic en el botón de acción de una fila: navega a la ficha del vehículo
    handleRowAction(event)
    {
        const vehicleId = event.detail.row.Id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: vehicleId,
                objectApiName: 'VRT_Vehicle__c',
                actionName: 'view'
            }
        });
    }

    get noResults()
    {
        return this.hasSearched && this.results.length === 0;
    }
}