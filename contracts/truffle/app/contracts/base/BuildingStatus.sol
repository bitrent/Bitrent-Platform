pragma solidity ^0.4.18;
import './Ownable.sol';

contract BuildingStatus is Ownable {
  /* Observer contract  */
  address public observer;

  /* Crowdsale contract */
  address public crowdsale;

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

  modifier onlyObserver() {
    require(msg.sender == observer || msg.sender == owner || msg.sender == address(this));
    _;
  }

  modifier onlyCrowdsale() {
    require(msg.sender == crowdsale || msg.sender == owner || msg.sender == address(this));
    _;
  }

  statusEnum public status;

  event StatusChanged(statusEnum newStatus);

  function setStatus(statusEnum newStatus) onlyCrowdsale  public {
      status = newStatus;
      emit StatusChanged(newStatus);
  }

  function changeStage(uint8 stage) public onlyObserver {
      if (stage==1) status = statusEnum.stage1;
      if (stage==2) status = statusEnum.stage2;
      if (stage==3) status = statusEnum.stage3;
      if (stage==4) status = statusEnum.stage4;
      if (stage==5) status = statusEnum.stage5;
  }
 
}