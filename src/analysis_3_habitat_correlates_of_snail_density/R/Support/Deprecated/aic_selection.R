# Function to do backward model selection using p-values, aic, or bic

aic_sel <- function( data_list = data_list, params = params, version = version, map = map, random = random , BIC_sel = T ){
  library(plyr)
  source("R/Support/missing_cont_val_update.R")

  mod_list <- list()
  terms_list <- list()
  Obj_list <- list()

  ind = 1
  remove_vec <- c()
  model.list = list()
  summ_stats = data.frame(matrix(NA, ncol = 6 , nrow = 1))
  colnames(summ_stats) = c("Model", "AIC", "BIC","Log_Lik","N_Params","Param")

  # Fit intercept model
  map$beta_c <- factor(rep(NA, length(map$beta_c)))
  map$beta_p <- factor(rep(NA, length(map$beta_p)))
  map$x_pq_cont_missing <- factor(rep(NA, length(map$x_pq_cont_missing)))

  data_list$x_pq_hat_est <- as.numeric(as.character(map$beta_p))
  Obj = TMBdebug::MakeADFun( data = data_list, parameters = params, DLL = version, map = map_update( map , params , data_list ), random = random)
  Opt = Optimize( Obj )

  # Save model objects
  mod_list[[ind]] <- Opt
  Obj_list[[ind]] <- Obj
  BIC <- 2 * Opt$objective + log(nrow(data_list$x_pq)) * length(Opt$par)
  AIC <- Opt$AIC; if(is.null(AIC)){ AIC = 1e6 }
  summ_stats <- rbind(summ_stats, (c("Base", AIC, BIC, Opt$objective,  length(Opt$par), NA)))

  # Save parameter estimates
  coef_save_p <- round(Opt$SD$value[which(names(Opt$SD$value) %in% c("beta_p"))], 3)
  coef_save_c <- round(Opt$SD$value[which(names(Opt$SD$value) %in% c("beta_c"))], 3)
  terms_list[[ind]] <- rbind( coef_save_p, coef_save_c )
  colnames(terms_list[[ind]]) <- colnames(data_list$x_cq)

  # Set lowest AIC to starting AIC
  if(BIC_sel == T){
    lowest_val <- BIC
  }
  if( BIC_sel == F){
    lowest_val <- AIC
  }


  # Run the next models
  ind <- ind + 1

  # FORWARD SELECTION
  # Loop model formulations to see if it improves AIC
  for(i in 1:ncol(data_list$x_cq)){

    # Change the map to turn parameters on
    map[["beta_p"]] <- as.character( map[["beta_p"]] )
    map[["beta_c"]] <- as.character( map[["beta_c"]] )
    map[["beta_c"]][i] <- i
    map[["beta_p"]][i] <- i
    map[["beta_c"]] <- factor(map[["beta_c"]])
    map[["beta_p"]] <- factor(map[["beta_p"]])
    data_list$x_pq_hat_est <- as.numeric(as.character(map$beta_p))

    # Fit model
    Obj = TMBdebug::MakeADFun( data = data_list, parameters = params, DLL = version, map = map_update( map , params , data_list ), random = random)
    Opt = Optimize( Obj )

    # Save model objects
    mod_list[[ind]] <- Opt
    Obj_list[[ind]] <- Obj
    BIC <- 2 * Opt$objective + log(nrow(data_list$x_pq)) * length(Opt$par)
    AIC <- Opt$AIC; if(is.null(AIC)){ AIC = NA }
    params_in_model <- paste(colnames(data_list$x_cq)[which(!is.na(as.character( map[["beta_p"]] )))], collapse = ", ")
    summ_stats <- rbind(summ_stats, (c("Base", AIC, BIC, Opt$objective,  length(Opt$par), params_in_model)))

    if(BIC_sel == T){
      val_sel <- BIC
    }
    if( BIC_sel == F){
      val_sel <- AIC
    }

    # Save parameter estimates
    if(is.null(Opt$SD$value) == T){
      coef_save <- rep("Did not converge", length(terms_list[[ind]]))
      terms_list[[ind]] <- coef_save
    }
    if(is.null(Opt$SD$value) == F) {
      coef_save_p <- round(Opt$SD$value[which(names(Opt$SD$value) %in% c("beta_p"))], 3)
      coef_save_c <- round(Opt$SD$value[which(names(Opt$SD$value) %in% c("beta_c"))], 3)
      terms_list[[ind]] <- rbind( coef_save_p, coef_save_c )
      colnames(terms_list[[ind]]) <- colnames(data_list$x_cq)
    }

    # Run the next models (turn of parameters if they dont do anything)
    if(is.null(Opt$SD$value) == T){
      map[["beta_p"]] <- as.character( map[["beta_p"]] )
      map[["beta_c"]] <- as.character( map[["beta_c"]] )
      map[["beta_c"]][i] <- NA
      map[["beta_p"]][i] <- NA
      map[["beta_c"]] <- factor(map[["beta_c"]])
      map[["beta_p"]] <- factor(map[["beta_p"]])
    }
    if(is.null(Opt$SD$value) == F) {
      if(lowest_val < val_sel){
        map[["beta_p"]] <- as.character( map[["beta_p"]] )
        map[["beta_c"]] <- as.character( map[["beta_c"]] )
        map[["beta_c"]][i] <- NA
        map[["beta_p"]][i] <- NA
        map[["beta_c"]] <- factor(map[["beta_c"]])
        map[["beta_p"]] <- factor(map[["beta_p"]])
      }
    }

    if(is.null(Opt$SD$value) == F){
      if(lowest_val > val_sel){
        lowest_val <- val_sel
      }
    }
    ind <- ind + 1
  }


  # BACKWARD SELECTION
  # Loop model formulations to see if it improves AIC
  params_left <- which(!is.na(as.character(map[["beta_p"]]))) # which parameters remain from forward selection
  for(i in params_left){

    # Change the map to turn parameters off
    map[["beta_p"]] <- as.character( map[["beta_p"]] )
    map[["beta_c"]] <- as.character( map[["beta_c"]] )
    map[["beta_c"]][i] <- NA
    map[["beta_p"]][i] <- NA
    map[["beta_c"]] <- factor(map[["beta_c"]])
    map[["beta_p"]] <- factor(map[["beta_p"]])
    data_list$x_pq_hat_est <- as.numeric(as.character(map$beta_p))

    # Fit model
    Obj = TMBdebug::MakeADFun( data = data_list, parameters = params, DLL = version, map = map_update( map , params , data_list ), random = random)
    Opt = Optimize( Obj )

    # Save model objects
    mod_list[[ind]] <- Opt
    Obj_list[[ind]] <- Obj
    BIC <- 2 * Opt$objective + log(nrow(data_list$x_pq)) * length(Opt$par)
    AIC <- Opt$AIC; if(is.null(AIC)){ AIC = NA }
    params_in_model <- paste(colnames(data_list$x_cq)[which(!is.na(as.character( map[["beta_p"]] )))], collapse = ", ")
    summ_stats <- rbind(summ_stats, (c("Base", AIC, BIC, Opt$objective,  length(Opt$par), params_in_model)))

    if(BIC_sel == T){
      val_sel <- BIC
    }
    if( BIC_sel == F){
      val_sel <- AIC
    }

    # Save parameter estimates
    if(is.null(Opt$SD$value) == T){
      coef_save <- rep("Did not converge", length(terms_list[[ind]]))
      terms_list[[ind]] <- coef_save
    }
    if(is.null(Opt$SD$value) == F) {
      coef_save_p <- round(Opt$SD$value[which(names(Opt$SD$value) %in% c("beta_p"))], 3)
      coef_save_c <- round(Opt$SD$value[which(names(Opt$SD$value) %in% c("beta_c"))], 3)
      terms_list[[ind]] <- rbind( coef_save_p, coef_save_c )
      colnames(terms_list[[ind]]) <- colnames(data_list$x_cq)
    }

    # Run the next models: Turn parameters back on if the new model didn't converge
    if(is.null(Opt$SD$value) == T){
      map[["beta_p"]] <- as.character( map[["beta_p"]] )
      map[["beta_c"]] <- as.character( map[["beta_c"]] )
      map[["beta_c"]][i] <- i
      map[["beta_p"]][i] <- i
      map[["beta_c"]] <- factor(map[["beta_c"]])
      map[["beta_p"]] <- factor(map[["beta_p"]])
    }
    if(is.null(Opt$SD$value) == F) {
      if(lowest_val < val_sel){ # Turn parameters back on if removal did not lower AIC
        map[["beta_p"]] <- as.character( map[["beta_p"]] )
        map[["beta_c"]] <- as.character( map[["beta_c"]] )
        map[["beta_c"]][i] <- i
        map[["beta_p"]][i] <- i
        map[["beta_c"]] <- factor(map[["beta_c"]])
        map[["beta_p"]] <- factor(map[["beta_p"]])
      }
    }

    if(is.null(Opt$SD$value) == F){
      if(lowest_val > val_sel){
        lowest_val <- val_sel
      }
    }
    ind <- ind + 1
  }

  # FIT THE FINAL MODEL
  data_list$x_pq_hat_est <- as.numeric(as.character(map$beta_p))
  Obj = TMBdebug::MakeADFun( data = data_list, parameters = params, DLL = version, map = map_update( map , params , data_list ), random = random)
  Opt = Optimize( Obj )

  # Save model objects
  mod_list[[ind]] <- Opt
  Obj_list[[ind]] <- Obj
  BIC <- 2 * Opt$objective + log(nrow(data_list$x_pq)) * length(Opt$par)
  AIC <- Opt$AIC; if(is.null(AIC)){ AIC = NA }
  params_in_model <- paste(colnames(data_list$x_cq)[which(!is.na(as.character( map[["beta_p"]] )))], collapse = ", ")
  summ_stats <- rbind(summ_stats, (c("Base", AIC, BIC, Opt$objective,  length(Opt$par), params_in_model)))

  # Save parameter estimates
  if(is.null(Opt$SD$value) == T){
    coef_save <- rep("Did not converge", length(terms_list[[ind]]))
    terms_list[[ind]] <- coef_save
  }
  if(is.null(Opt$SD$value) == F) {
    coef_save_p <- round(Opt$SD$value[which(names(Opt$SD$value) %in% c("beta_p"))], 3)
    coef_save_c <- round(Opt$SD$value[which(names(Opt$SD$value) %in% c("beta_c"))], 3)
    terms_list[[ind]] <- rbind( coef_save_p, coef_save_c )
    colnames(terms_list[[ind]]) <- colnames(data_list$x_cq)
  }


  # Return results
  results_list = list(summ_stats = summ_stats, mod_list = mod_list, terms_list = terms_list, Obj_list = Obj_list)
  return(results_list)
}
