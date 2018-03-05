pragma solidity ^0.4.18;

import './base/PermissionManager.sol';
import './base/OraclizeC.sol';
import './base/BuildingStatus.sol';
import './Hold.sol';
import './Stage.sol';
/**
 * @author Emil Dudnyk
 */
contract Observer is OraclizeC {
  uint8 public stages = 5;
  uint8 public currentStage;
  mapping(uint8 => address) public stagesContract;

  struct stagesData {
    bool isWork;
    bool isFinished;
  }

  mapping(address => stagesData) public stagesList;

  BuildingStatus public statusI;
  PermissionManager public permissionManager;
  Hold public hold;

  event updateWork(uint8 currentStage, uint blockTimestamp);
  event startStageLogAddr(address stageAddr, uint blockTimestamp);
  event unlockHold(uint8 currentStage, uint blockTimestamp);

  modifier onlyPermitted() {
    require(msg.sender == owner || msg.sender == address(this) || permissionManager.isPermitted(msg.sender));
    _;
  }

  function Observer(address pm) payable public {
    permissionManager = PermissionManager(pm);
    currentStage = 0;
    updateInterval = 1 * day;
    gasLimit = 400000;
  }

  function setPermissionManager(address _permadr) public onlyOwner {
    require(_permadr != 0x0);
    permissionManager = PermissionManager(_permadr);
  }

  function setBuildingStatus(address _statusI) public onlyOwner {
    require(_statusI != 0x0);
    statusI = BuildingStatus(_statusI);
  }

  function setHold(address _hold) public onlyOwner {
    require(_hold != 0x0);
    hold = Hold(_hold);
  }

  function setStagesContract(uint8 _index, address _addr) public onlyPermitted {
    require(_index > 0 && _index <= stages);
    require(address(Stage(_addr)) != 0x0);
    require(!stagesList[_addr].isWork || stagesList[_addr].isWork);
    stagesList[_addr].isFinished = false;
    stagesList[_addr].isWork = false;
    stagesContract[_index] = _addr;
  }

  function nextStage(uint8 stage) public onlyPermitted {
    require(stage <= stages);
    statusI.changeStage(stage);
    hold.changeStage();
    unlockHold(stage, now);
  }

  function nextStageAndReleaseETH(uint8 stage) public onlyPermitted {
    require(stage <= stages);
    statusI.changeStage(stage);
    hold.changeStageAndReleaseETH();
    unlockHold(stage, now);
  }

  function __callback(bytes32 myid, string result) public {
    require(msg.sender == oraclize_cbAddress() && validIds[myid]);
    delete validIds[myid];

    updateStageWork();
    result; // Silence compiler warnings
  }

  function update(uint delay) private {
    if (oraclize_getPrice("URL") > this.balance) {
      //stop if we don't have enough funds anymore
      state = State.Stopped;
      LogOraclizeQuery("Oraclize query was NOT sent", this.balance, block.timestamp);
    } else {
      bytes32 queryId = oraclize_query(delay, "URL", "", gasLimit);
      validIds[queryId] = true;
    }
  }

  function start() payable public onlyPermitted {
    updateStageWork();
  }

  function updateStageWork() private {

    if (state != State.Stopped && currentStage <= stages) {
      if (currentStage == 0) {
        if (startStage(1)) {
          currentStage = 1;
          state = State.Active;
        }
      } else {
        address curIndexStageAddr = stagesContract[currentStage];
        uint8 oldCurrentStage = currentStage;
        if (curIndexStageAddr != 0x0) {
          if (Stage(curIndexStageAddr).getStatus()) {
            stagesList[curIndexStageAddr].isFinished = true;
            stagesList[curIndexStageAddr].isWork = false;

            currentStage++;
            if (currentStage <= stages) {
              startStage(currentStage);
            } else {
              state = State.Stopped;
            }

            nextStage(oldCurrentStage);
          }
        }

      }
      update(updateInterval);
    } else {
      if (currentStage > stages) {
        state = State.Stopped;
      }
    }
    updateWork(currentStage, now);
  }

  function startStage(uint8 index) private returns (bool) {
    if (index <= stages) {
      address curIndexStageAddr = stagesContract[index];
      if (curIndexStageAddr != 0x0) {
        if (Stage(curIndexStageAddr).start()) {
          startStageLogAddr(curIndexStageAddr, now);
          stagesList[curIndexStageAddr].isWork = true;
          return true;
        }
      }
    }
    return false;
  }

}