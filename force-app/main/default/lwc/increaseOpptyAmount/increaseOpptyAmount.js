import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import updateOpportunityAmounts from '@salesforce/apex/IncreaseOpportunityAmountController.updateOpportunityAmounts';

const CHANGE_TYPE_OPTIONS = [
    { label: 'Increase by percentage', value: 'INCREASE_PERCENT' },
    { label: 'Decrease by percentage', value: 'DECREASE_PERCENT' },
    { label: 'Increase by value', value: 'INCREASE_VALUE' },
    { label: 'Decrease by value', value: 'DECREASE_VALUE' },
    { label: 'Replace with value', value: 'REPLACE_VALUE' }
];

const VALUE_LABELS_BY_CHANGE_TYPE = {
    INCREASE_PERCENT: 'Percentage increase (%)',
    DECREASE_PERCENT: 'Percentage decrease (%)',
    INCREASE_VALUE: 'Increase amount',
    DECREASE_VALUE: 'Decrease amount',
    REPLACE_VALUE: 'New amount'
};

const SUCCESS_MESSAGE_BY_CHANGE_TYPE = {
    INCREASE_PERCENT: (updatedCount, value) => `${updatedCount} Opportunity Amount(s) increased by ${value}%.`,
    DECREASE_PERCENT: (updatedCount, value) => `${updatedCount} Opportunity Amount(s) decreased by ${value}%.`,
    INCREASE_VALUE: (updatedCount, value) => `${updatedCount} Opportunity Amount(s) increased by ${value}.`,
    DECREASE_VALUE: (updatedCount, value) => `${updatedCount} Opportunity Amount(s) decreased by ${value}.`,
    REPLACE_VALUE: (updatedCount, value) => `${updatedCount} Opportunity Amount(s) replaced with ${value}.`
};

export default class IncreaseOpptyAmount extends LightningElement {
    @api recordId;

    changeType = CHANGE_TYPE_OPTIONS[0].value;
    value;
    isLoading = false;

    changeTypeOptions = CHANGE_TYPE_OPTIONS;

    get valueInputLabel() {
        return VALUE_LABELS_BY_CHANGE_TYPE[this.changeType];
    }

    get isApplyDisabled() {
        return this.isLoading || this.value === undefined || this.value === null || this.value === '';
    }

    handleChangeTypeChange(event) {
        this.changeType = event.detail.value;
    }

    handleValueChange(event) {
        this.value = event.target.value;
    }

    handleApply() {
        if (this.isApplyDisabled) {
            return;
        }

        this.isLoading = true;

        updateOpportunityAmounts({ accountId: this.recordId, changeType: this.changeType, value: this.value })
            .then((updatedCount) => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: SUCCESS_MESSAGE_BY_CHANGE_TYPE[this.changeType](updatedCount, this.value),
                        variant: 'success'
                    })
                );
                this.closeAction();
            })
            .catch((error) => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error updating Opportunities',
                        message: (error && error.body && error.body.message) || error.message,
                        variant: 'error'
                    })
                );
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    closeAction() {
        // No-op if not launched as a screen action; safe to call in either context.
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}
