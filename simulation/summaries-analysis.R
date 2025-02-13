## script to compute summary statistics for the analysis of the simulation study
## results

## performance measure and MCSE functions
## -----------------------------------------------------------------------------
## coverage
coverage <- function(lower, upper, true, na.rm = FALSE) {
    mean((lower <= true) & (upper >= true), na.rm = na.rm)
}
coverage_mcse <- function(lower, upper, true, na.rm = FALSE) {
    cov <- coverage(lower = lower, upper = upper, true = true, na.rm = na.rm)
    n <- sum(!is.na(lower) & !is.na(upper))
    mcse <- sqrt(cov*(1 - cov)/n)

}

## bias
bias <- function(estimate, true, na.rm = FALSE) {
    mean(estimate, na.rm = na.rm) - true
}
bias_mcse <- function(estimate, na.rm = FALSE) {
    n <- sum(!is.na(estimate))
    sd(estimate, na.rm = na.rm)/n
}

## relative bias
relbias <- function(estimate, true, na.rm = FALSE) {
    (mean(estimate, na.rm = na.rm) - true)/true
}
relbias_mcse <- function(estimate, true, na.rm = FALSE) {
    n <- sum(!is.na(estimate))
    sd(estimate, na.rm = na.rm)/n/abs(true)
}

## median bias
medianbias <- function(estimate, true, na.rm = FALSE) {
    median(estimate, na.rm = na.rm) - true
}
## medianbias_mcse <- function(estimate, na.rm = FALSE) {
##     ## TODO What is it?
## }

## CI width
width <- function(lower, upper, na.rm = FALSE) {
    mean(upper - lower, na.rm = na.rm)
}
width_mcse <- function(lower, upper, na.rm = FALSE) {
    n <- sum(!is.na(lower) & !is.na(upper))
    sd(upper - lower, na.rm = na.rm)/sqrt(n)
}

## relative CI width
relwidth <- function(lower, upper, reflower, refupper, na.rm = FALSE) {
    mean((upper - lower)/(refupper - reflower), na.rm  = na.rm)
}
relwidth_mcse <- function(lower, upper, reflower, refupper, na.rm = FALSE) {
    wi <- upper - lower
    nw <- sum(!is.na(wi))
    wri <- refupper - reflower
    nwr <- sum(!is.na(wri))
    w <- mean(wi, na.rm  = na.rm)
    sdw <- sd(wi, na.rm  = na.rm)/sqrt(nw)
    wr <- mean(wri, na.rm  = na.rm)
    sdwr <- sd(wri, na.rm  = na.rm)/sqrt(nwr)
    corw <- cor(wi, wri)
    ## approximation (when w and wr are positive and coefficient of variation of
    ## w and wr are small, see equation 8 in
    ## https://doi.org/10.1007/s00362-012-0429-2)
    w/wr*sqrt(sdw^2/w^2 + sdw^2/wr^2) #- 2*sdw*sdwr*corw/w/wr)
}
relwidth_quantile <- function(lower, upper, reflower, refupper, quantile = 0.5,
                              na.rm = FALSE) {
    quantile(x = (upper - lower)/(refupper - reflower), probs = quantile,
             na.rm = na.rm)
}

## empirical variance
empvar <- function(estimate, na.rm = FALSE) {
    n <- sum(!is.na(estimate))
    var(estimate, na.rm = na.rm)*(n - 1)/n
}
empvar_mcse <- function(estimate, na.rm = FALSE) {
    n <- sum(!is.na(estimate))
    var(estimate, na.rm = na.rm)*sqrt(2/(n - 1))
}

## empirical standard error
empse <- function(estimate, na.rm = FALSE) {
    sqrt(empvar(estimate, na.rm = na.rm))
}
empse_mcse <- function(estimate, na.rm = FALSE) {
    n <- sum(!is.na(estimate))
    sd(estimate, na.rm = na.rm)/sqrt(2*(n - 1))
}

## mean square error
mse <- function(estimate, true, na.rm = FALSE) {
    mean((estimate - true)^2, na.rm = na.rm)
}
mse_mcse <- function(estimate, true, na.rm = FALSE) {
    n <- sum(!is.na(estimate))
    sd((estimate - true)^2, na.rm = na.rm)/n
}

## root mean square error
rmse <-  function(estimate, true, na.rm = FALSE) {
    mse(estimate, true, na.rm = na.rm)
}
rmse_mcse <-  function(estimate, true, na.rm = FALSE) {
    mse_mcse(estimate, true, na.rm = na.rm)/
        (4*mse(estimate, true, na.rm = na.rm))

}

## correlation between CI skewness and data skewness
corskew <- function(CIskew, dataskew, na.rm = FALSE) {
    if (all(is.na(CIskew)) || is.null(CIskew)) {
        return(NA)
    } else {
        if (na.rm == TRUE) {
            use <- "pairwise.complete.obs"
        } else {
            use <- "everything"
        }
        suppressWarnings({
            cor(x = CIskew, y = dataskew, use = use)
        })
    }
}
corskew_mcse <- function(CIskew, dataskew, na.rm = FALSE) {
    cor <- corskew(CIskew, dataskew, na.rm)
    n <- sum(!is.na(CIskew) & !is.na(dataskew))
    sqrt((1 - cor^2)/(n - 2))
}

## Cohen's kappa between CI skewness and data skewness
kappaskew <- function(CIskew, dataskew, na.rm = FALSE, mcse = FALSE) {
    signCI <- sign(CIskew)
    signCI <- ifelse(signCI == 0, NA, signCI)
    signdata <- sign(dataskew)
    signdata <- ifelse(signdata == 0, NA, signdata)
    if (all(is.na(signCI))) {
        return(NA_real_)
    }
    if (na.rm == FALSE) {
        if (any(is.na(c(signCI, signdata)))) return(NA_real_)
    }
    kappa <- psych::cohen.kappa(cbind(signCI, signdata))
    if (mcse == FALSE) {
        return(kappa$kappa)
    } else {
        return(sqrt(kappa$var.kappa))
    }
}
kappaskew_mcse <- function(CIskew, dataskew, na.rm = FALSE) {
    kappaskew(CIskew, dataskew, na.rm, mcse = TRUE)
}


## process data from simulation study
library(data.table)
library(sn)
library(psych)
library(parallel)
detectCores()
path <- "simulation/RData/CIs/"
files <- list.files(path = path)
pb <- txtProgressBar(min = 1, max = length(files), style = 3)
## summarydat <- vector("list", length = length(files))
## for (i in seq(1, length(files))) {
summarydat <- mclapply(mc.cores = pmax(detectCores() - 1, 1),
                       X = seq_along(files), FUN = function(i) {
    setTxtProgressBar(pb = pb, value = i)
    file <- files[i]

    ## get intermediate data from simulations of a certain condition
    condList <- readRDS(file = paste0(path, file))

    ## extract information in simulation condition
    condition <- condList$pars
    truemean <- condition$effect
    if (condition$I2 == 0 | condition$dist == "Gaussian") {
        truemedian <- condition$effect
    } else {
        ## compute the median of the corresponding skew normal distribution
        n <- rep(condition$sampleSize, condition$k)
        if (condition$large != 0) n[seq_len(condition$large)] <- n[seq_len(condition$large)]*10
        eps2 <- 1/condition$k*sum(2/n)
        tau2 <- eps2*condition$I2/(1 - condition$I2)
        if (condition$dist == "snr") {
            alpha <- 8
        } else {
            alpha <- -8
        }
        delta <- alpha/sqrt(1 + alpha^2)
        omega <- sqrt(tau2)/sqrt(1 - 2*delta^2/pi)
        xi <- condition$effect - omega*delta*sqrt(2/pi)
        truemedian <- sn::qsn(p = 0.5, alpha = alpha, omega = omega, xi = xi)
    }
    condition$effect_median <- truemedian

    ## extract estimates, CIs, AUCC, per method/repetion
    estimates <- do.call("rbind", lapply(X = seq_along(condList$cis), FUN = function(j) {
        ## cbind("repetition" = j, condList$cis[[j]]$CI)
        merge(cbind("repetition" = j, condList$cis[[j]]$CI),
              data.frame(condList$cis[[j]]$aucc, aucc_ratio = condList$cis[[j]]$aucc_ratio$aucc_ratio),
              all = TRUE)
    }))
    estimates <- as.data.table(estimates)
    # 173 - 177

    ## add RE-MA confidence interval as reference for computing relative width
    ## lowerrema, upperrema
    estimates_rema_none <- estimates[method == "reml_ci_additive_none",
                                     .(repetition, lower_rema_none = lower,
                                       upper_rema_none = upper)]
    estimates_rema_dl <- estimates[method == "reml_ci_additive_DL",
                                   .(repetition, lower_rema_dl = lower,
                                     upper_rema_dl = upper)]
    estimates_rema_reml <- estimates[method == "reml_ci_additive_REML",
                                     .(repetition, lower_rema_reml = lower,
                                       upper_rema_reml = upper)]
    estimates <- merge(estimates, estimates_rema_none)
    estimates <- merge(estimates, estimates_rema_dl)
    estimates <- merge(estimates, estimates_rema_reml)
    none_mtds <- c("hk_ci_additive_none", "reml_ci_additive_none",
                   "tippett_ci_additive_none", "pearson_ci_additive_none",
                   "wilkinson_ci_additive_none", "edgington_ci_additive_none")
    DL_mtds <- c("hk_ci_additive_DL", "reml_ci_additive_DL", "hc_ci_additive_DL",
                 "tippett_ci_additive_DL", "pearson_ci_additive_DL",
                 "wilkinson_ci_additive_DL", "edgington_ci_additive_DL")
    REML_mtds <- c("hk_ci_additive_REML", "reml_ci_additive_REML",
                   "tippett_ci_additive_REML", "pearson_ci_additive_REML",
                   "wilkinson_ci_additive_REML", "edgington_ci_additive_REML")
    estimates$lower_rema <- ifelse(estimates$method %in% none_mtds,
                                   estimates$lower_rema_none,
                            ifelse(estimates$method %in% DL_mtds,
                                   estimates$lower_rema_dl,
                                   estimates$lower_rema_reml))
    estimates$upper_rema <- ifelse(estimates$method %in% none_mtds,
                                   estimates$upper_rema_none,
                            ifelse(estimates$method %in% DL_mtds,
                                   estimates$upper_rema_dl,
                                   estimates$upper_rema_reml))

    ## compute CI skewnewss
    estimates$CIskew <- ifelse(estimates$method %in%
                               c("hk_ci_additive_none", "reml_ci_additive_none",
                                 "hc_ci_additive_DL", "hk_ci_additive_DL",
                                 "reml_ci_additive_DL", "hk_ci_additive_REML",
                                 "reml_ci_additive_REML"),
                               0, (estimates$upper + estimates$lower - 2*estimates$estimate)/
                                  (estimates$upper - estimates$lower))

    ## extract data skewness per repetition and heterogeneity estimator
    skewness <- do.call("rbind", lapply(X = seq(1, length(condList$cis)), FUN = function(j) {
        cbind("repetition" = j, data.frame(as.list(condList$cis[[j]]$data_skewness)))
    }))
    skewness <- as.data.table(skewness)
    ## merge the data skewness to method with corresponding heterogeneity
    estimates <- merge(estimates, skewness, by = "repetition")
    estimates$dataskew <- ifelse(estimates$method %in% none_mtds,
                                 estimates$none,
                          ifelse(estimates$method %in% DL_mtds, estimates$DL,
                                 estimates$REML))

    ## drop unnecessary columns
    estimates <- estimates[,c("lower_rema_none","upper_rema_none",
                              "lower_rema_dl","upper_rema_dl",
                              "lower_rema_reml","upper_rema_reml",
                              "none", "DL", "REML"):=NULL]
    ## TODO we may want to save all estimates combined with the condition?
    ## (perhaps that's too big, but would be the most fine-grained format of the
    ## simulation results apart from the raw data)

    ## compute performance measures and their MCSEs
    summaries <-
        estimates[,
                  .(
                      prop_converged_estimate = mean(!is.na(estimate)),
                      prop_converged_ci = mean(!is.na(lower) & !is.na(upper)),
                      bias_mean = bias(estimate, truemean, na.rm = TRUE),
                      bias_median = bias(estimate, truemedian, na.rm = TRUE),
                      bias_mcse = bias_mcse(estimate, na.rm = TRUE),
                      relbias_mean = relbias(estimate, truemean, na.rm = TRUE),
                      relbias_mean_mcse = relbias_mcse(estimate, truemean, na.rm = TRUE),
                      relbias_median = relbias(estimate, truemedian, na.rm = TRUE),
                      relbias_median_mcse = relbias_mcse(estimate, truemedian, na.rm = TRUE),
                      var = empvar(estimate, na.rm = TRUE),
                      var_mcse = empvar_mcse(estimate, na.rm = TRUE),
                      empse = empse(estimate, na.rm = TRUE),
                      empse_mcse = empse_mcse(estimate, na.rm = TRUE),
                      width = width(lower, upper, na.rm = TRUE),
                      width_mcse = width_mcse(lower, upper, na.rm = TRUE),
                      relwidth_rema = relwidth(lower, upper, lower_rema, upper_rema, na.rm = TRUE),
                      relwidth_rema_mcse = relwidth_mcse(lower, upper, lower_rema, upper_rema, na.rm = TRUE),
                      relwidth_rema_50 = relwidth_quantile(lower, upper, lower_rema, upper_rema, 0.5, na.rm = TRUE),
                      relwidth_rema_10 = relwidth_quantile(lower, upper, lower_rema, upper_rema, 0.1, na.rm = TRUE),
                      relwidth_rema_90 = relwidth_quantile(lower, upper, lower_rema, upper_rema, 0.9, na.rm = TRUE),
                      mse_mean = mse(estimate, truemean, na.rm = TRUE),
                      mse_mean_mcse = mse_mcse(estimate, truemean, na.rm = TRUE),
                      mse_median = mse(estimate, truemedian, na.rm = TRUE),
                      mse_median_mcse = mse_mcse(estimate, truemedian, na.rm = TRUE),
                      rmse_mean = rmse(estimate, truemean, na.rm = TRUE),
                      rmse_mean_mcse = rmse_mcse(estimate, truemean, na.rm = TRUE),
                      rmse_median = rmse(estimate, truemedian, na.rm = TRUE),
                      rmse_median_mcse = rmse_mcse(estimate, truemedian, na.rm = TRUE),
                      coverage_mean = coverage(lower, upper, truemean, na.rm = TRUE),
                      coverage_mean_mcse = coverage_mcse(lower, upper, truemean, na.rm = TRUE),
                      coverage_median = coverage(lower, upper, truemedian, na.rm = TRUE),
                      coverage_median_mcse = coverage_mcse(lower, upper, truemedian, na.rm = TRUE),
                      correlation_skew = corskew(CIskew, dataskew, na.rm = TRUE),
                      correlation_skew_mcse = corskew_mcse(CIskew, dataskew, na.rm = TRUE),
                      kappa_skew = kappaskew(CIskew, dataskew, na.rm = TRUE),
                      kappa_skew_mcse = kappaskew_mcse(CIskew, dataskew, na.rm = TRUE),
                      ciskew_mean = mean(CIskew, na.rm = TRUE),
                      ciskew_mean_mcse = bias_mcse(CIskew, na.rm = TRUE),
                      ciskew_median = median(CIskew, na.rm = TRUE),
                      ciskew_max = max(CIskew, na.rm = TRUE),
                      ciskew_min = min(CIskew, na.rm = TRUE),
                      aucc_mean = mean(aucc, na.rm = TRUE),
                      aucc_mean_mcse = bias_mcse(aucc, na.rm = TRUE),
                      aucc_median = median(aucc, na.rm = TRUE),
                      aucc_ratio_mean = mean(aucc_ratio, na.rm = TRUE),
                      aucc_ratio_mean_mcse = bias_mcse(aucc_ratio, na.rm = TRUE),
                      aucc_ratio_median = median(aucc_ratio, na.rm = TRUE),
                      aucc_ratio_10 = quantile(aucc_ratio, probs = 0.1, na.rm = TRUE),
                      aucc_ratio_90 = quantile(aucc_ratio, probs = 0.9, na.rm = TRUE)
                  ),
                  method]
    return(cbind(condition, summaries))
    })
##     summarydat[[i]] <- cbind(condition, summaries)
## }

summaryDF <- do.call("rbind", summarydat)
write.csv(summaryDF, file = "simulation/RData/simulation-summaries.csv", row.names = FALSE)
