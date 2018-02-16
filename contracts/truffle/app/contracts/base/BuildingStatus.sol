pragma solidity ^0.4.18;

contract BuildingStatus {

    enum statusEnum { 
        crowdsale, 
        refund,
        preparation_works,
        building_permit,
        design_technical_documentation,
        utilities_outsite,
        construction_residential,
        frame20,
        frame40,
        frame60,
        frame80,
        frame100,
        stage1,
        stage2,
        stage3,
        stage4,
        stage5,
        facades20,
        facades40,
        facades60,
        facades80,
        facades100,
        engineering,
        finishing,
        construction_parking,
        civil_works,
        engineering_further,
        commisioning_project,
        completed
    }

    modifier notCompleted() {
        require(status != statusEnum.completed);
        _;
    }

    statusEnum public status; 

    event StatusChanged(statusEnum newStatus);

    function setStatus(statusEnum newStatus) public {
        status = newStatus;
        StatusChanged(newStatus);
    }
 
}