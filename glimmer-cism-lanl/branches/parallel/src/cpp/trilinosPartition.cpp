#include <iostream>
#include "Epetra_LocalMap.h"
#ifdef _MPI
  #include "Epetra_MpiComm.h"
#else
  #include "Epetra_SerialComm.h"
#endif
#include "Teuchos_RCP.hpp"


// Define global variables.
static Teuchos::RCP<const Epetra_Map> partitionMap;


extern "C" {

  // doPartition and getPartition use Epetra to partition the global
  // problem in parallel. 
  // This is needed for serial-glimmer and parallel-trilinos,
  // These function will not be needed with a distributed glimmer
  // since the PDE code will pick the partitioning.

  void dopartition_(int& matrixSize, int& mySize) {
#ifdef _MPI
    Epetra_MpiComm comm(MPI_COMM_WORLD);
#else
    Epetra_SerialComm comm;
#endif
    partitionMap = Teuchos::rcp(new Epetra_Map(matrixSize,1,comm) );
    mySize = partitionMap->NumMyElements();

    cout << "Trilinos Partition: doPartition has mySize = " << mySize << endl;
  }

  void getpartition_(int& mySize, int* myIndicies) {

      // Copy indices into array to send back to glimmer
      partitionMap->MyGlobalElements(myIndicies);

  }
} // extern"C"
