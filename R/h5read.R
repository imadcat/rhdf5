
h5read <- function(file, name, index=NULL, start=NULL, stride=NULL, block=NULL, count=NULL, compoundAsDataFrame = TRUE, callGeneric = TRUE, read.attributes=FALSE, ... ) {
  loc = h5checktypeOrOpenLoc(file, readonly=TRUE)

  if (!H5Lexists(loc$H5Identifier, name)) {
    h5closeitLoc(loc)
    stop("Object ",name," does not exist in this HDF5 file.")
  } else {
    oid = H5Oopen(loc$H5Identifier, name)
    type = H5Iget_type(oid)
    num_attrs = H5Oget_num_attrs(oid)
    if (is.na(num_attrs)) { num_attrs = 0 }
    H5Oclose(oid)
    if (type == "H5I_GROUP") {
      gid <- H5Gopen(loc$H5Identifier, name)
      obj = h5dump(gid, start=start, stride=stride, block=block, count=count, compoundAsDataFrame = compoundAsDataFrame, callGeneric = callGeneric, ...)
      H5Gclose(gid)
    } else {
      if (type == "H5I_DATASET") {
        try( { h5dataset <- H5Dopen(loc$H5Identifier, name) } )
        try( { h5spaceFile <- H5Dget_space( h5dataset ) } )
        h5spaceMem = NULL
        if (!is.null(index)) {
          s <- H5Sget_simple_extent_dims(h5spaceFile)$size
          if (length(index) != length(s)) {
            stop("length of index has to be equal to dimensional extension of HDF5 dataset.")
          }
          for (i in seq_len(length(index))) {
            if (is.null(index[[i]])) {
              index[[i]] = seq_len(s[i])
            }
          }
          size = 0
          try ( { size = H5Sselect_index ( h5spaceFile, index) } )
          h5spaceMem = H5Screate_simple(size)
        } else {
          if (any(c(!is.null(start), !is.null(stride), !is.null(count), !is.null(block)))) {
            size = 0
            try( { size = H5Sselect_hyperslab ( h5spaceFile, start=start, stride = stride, count=count, block  = block) } )
            h5spaceMem = H5Screate_simple(size)
          }
        }
        obj <- NULL
        try( { obj <- H5Dread( h5dataset = h5dataset, h5spaceFile = h5spaceFile, h5spaceMem = h5spaceMem, compoundAsDataFrame=compoundAsDataFrame, ...) } )
        if (!is.null(h5spaceMem)) {
          try( { H5Sclose(h5spaceMem) } )
        }
        if (!is.null(index)) {
          I = list()
          for (i in seq_len(length(index))) {
            tmp = unique(sort(index[[i]]))
            I[[i]] = match(index[[i]], tmp)
          }
          obj <- do.call('[', c(list(obj),I,drop=FALSE))
        }
        try( { H5Sclose(h5spaceFile) } )
        try( { H5Dclose(h5dataset) } )
        
        cl <- attr(obj,"class")
        if (!is.null(cl) & callGeneric) {
          if (exists(paste("h5read",cl,sep="."),mode="function")) {
            obj <- do.call(paste("h5read",cl,sep="."), args=list(obj = obj))
          }
        }
      } else {
        message("Reading of object type not supported.")
        obj <- NULL
      } ## DATASET
    } ## GROUP
    if (read.attributes & (num_attrs > 0) & !is.null(obj)) {
      for (i in seq_len(num_attrs)) {
        A = H5Aopen_by_idx(loc$H5Identifier, n = i-1, objname = name)
        attrname <- H5Aget_name(A)
        if (attrname != "dim") {
          attr(obj, attrname) = H5Aread(A)
        }
        H5Aclose(A)
      }
    }
  }  # !H5Lexists
  h5closeitLoc(loc)

  obj
}
