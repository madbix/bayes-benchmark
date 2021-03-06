require("bnlearn")

gen.discrete.bn = function(vars, parents) {
  bn = empty.graph(vars)
  modelstring(bn) = gen.modelstring(vars, parents)
  return(bn)
}

gen.modelstring = function(vars, parents) {
  res = ""
  for (var in vars) {
    res = paste(res, "[", var, sep="")
    if (length(parents[[var]]) > 0) {
      res = paste(res, "|", sep="")
      for (parent in parents[[var]]) {
        res = paste(res, parent, ":", sep="")
      }
      res = substr(res, 1, nchar(res) - 1)
    }
    res = paste(res, "]", sep="")
  }
  return(res)
}

gen.discrete.bn.fitted = function(vars, dims, parents, probs) {
  
  nodes = list()
  
  nodes_to_process = vars
  
  while (length(nodes_to_process) > 0)
    for (node in nodes_to_process) {
      
      # All parents must have been processed
      parents.ok = TRUE
      for (parent in parents[[node]])
        if(is.null(nodes[[parent]])) {
          parents.ok = FALSE
          next
        }
      if (!parents.ok)
        next
      
      nodes_to_process = setdiff(nodes_to_process, node)
      
      cfgs = expand.grid(lapply(c(node, parents[[node]]), function(x) {return(dims[[x]])}))
      names(cfgs) = c(node, parents[[node]])
      
      # cfgs must be correctly ordered here (node names and values) to match the
      # order in wich are given the conditional probabilities in the file
      prob = table(cfgs)
      for (i in 1:prod(dim(prob))) {
        prob.vector = probs[[node]][[(i - 1) %/% length(dims[[node]]) + 1]]
        prob[i] = prob.vector[(i - 1) %% length(dims[[node]]) + 1]
      }
      
      varDim = dim(prob)[1]
      parDim = prod(dim(prob)[-1])
      for (i in 0:(parDim - 1)) {
        
        tmp = prob[(i * varDim + 1):(i * varDim + varDim)]
        
        if (any(tmp < 0) || sum(tmp) == 0)
          stop("inconcistency in the probability table of node \"", node,
               "\" (total probs ", i + 1, ").")
        
        err = min(1 - sum(tmp), (100 - sum(tmp)) / 100)
        if (err > 0.001)
          warning("probability table of node \"", node,
                  "\" may be inconsistent, missing ", err,
                  " to 100 % (row ", i + 1, ").")
        
        prob[(i * varDim + 1):(i * varDim + varDim)] = tmp / sum(tmp)
      }
      
      children = names(parents)[vapply(parents, function(x) any(x == node), logical(1))]
      
      nodes[[node]] = structure(list(
        node = node,
        parents = parents[[node]],
        children = children,
        prob = prob), class = "bn.fit.dnode")
    }

  bn.fitted = structure(nodes, class = "bn.fit")
}

gen.dataset.from.fitted.bn = function(bn.fitted, n) {
#   
#   data = list()
#   nodes_to_process = names(bn.fitted)
#   
#   while (length(nodes_to_process) > 0)
#     for (node in nodes_to_process) {
#       
#       parents = bn.fitted[[node]]$parents
#       dims = names(margin.table(bn.fitted[[node]]$prob, 1))
#       probs = bn.fitted[[node]]$prob
#       
#       # All parents must have been processed
#       parents.ok = TRUE
#       for (parent in parents)
#         if(is.null(data[[parent]])) {
#           parents.ok = FALSE
#           next
#         }
#       if (!parents.ok)
#         next
#       
#       nodes_to_process = setdiff(nodes_to_process, node)
#       
#       # Simplest case : no parents
#       if (length(parents) == 0) {
#         data[[node]] = sample(dims, n, prob = probs, replace = TRUE)
#         next
#       }
#       
#       # Fill with parent's values
#       par_dims = NULL
#       for (parent in parents) {
#         if (length(par_dims) == 0)
#           par_dims = names(margin.table(bn.fitted[[parent]]$prob, 1))
#         else {
#           tmp = c()
#           for (dim1 in par_dims) {
#             for (dim2 in names(margin.table(bn.fitted[[parent]]$prob, 1))) {
#               tmp = c(tmp, paste(dim1, ":", dim2, sep=""))
#             }
#           }
#           par_dims = tmp
#         }
#         if (is.null(data[[node]]))
#           data[[node]] = data[[parent]]
#         else
#           data[[node]] = apply(cbind(data[[node]], data[[parent]]), 1, paste, collapse = ":")
#       }
#       
#       # Transform parent's values
#       k = 0
#       for (dim in par_dims) {
#         data[[node]][data[[node]] == dim] = sample(
#               dims,
#               length(which(data[[node]] == dim)),
#               prob = probs[(k * length(dims) + 1):((k + 1) * length(dims))],
#               replace = TRUE)
#         k = k + 1
#       }
#     }
#   
#   for (node in names(bn.fitted)) {
#     data[[node]] = factor(data[[node]], dimnames(bn.fitted[[node]]$prob)[[1]])
#   }
#   
#   return(as.data.frame(data))
#   return(.Call("rbn_discrete", fitted = bn.fitted, n = as.integer(n), debug = FALSE, PACKAGE = "bnlearn"))
  return(rbn(x=bn.fitted, n=n))
}

gen.dataset = function(vars, dims, parents, probs, n) {
  
  data = list()
  vars_to_compute = vars
  
  while (length(vars_to_compute) > 0)
    for (var in vars_to_compute) {
      
      # All parents must have been processed
      parents.ok = TRUE
      for (parent in parents[[var]])
        if(is.null(data[[parent]])) {
          parents.ok = FALSE
          next
        }
      
      if (!parents.ok)
        next
      
      vars_to_compute = setdiff(vars_to_compute, var)
      
      # Simplest case : no parents
      if (length(parents[[var]]) == 0) {
        data[[var]] = sample(dims[[var]], n, prob = probs[[var]][[1]], replace = TRUE)
        next
      }
      
      # Fill with parent's values
      parDim = NULL
      for (parent in parents[[var]]) {
        if (length(parDim) == 0)
          parDim = dims[[parent]]
        else {
          tmp = c()
          for (dim1 in parDim) {
            for (dim2 in dims[[parent]]) {
              tmp = c(tmp, paste(dim1, ":", dim2, sep=""))
            }
          }
          parDim = tmp
        }
        if (is.null(data[[var]]))
          data[[var]] = data[[parent]]
        else
          data[[var]] = apply(cbind(data[[var]], data[[parent]]), 1, paste, collapse = ":")
      }
      
      # Transform parent's values
      k = 0
      for (dim in parDim) {
        k = k + 1
        data[[var]][data[[var]] == dim] = sample(dims[[var]], length(which(data[[var]] == dim)), prob = probs[[var]][[k]], replace = TRUE)
      }
      
    }
  
  as.data.frame(data)
}

gen.network.from.file = function(network) {
  source(paste("networks_params/", network, ".R", sep=""))
  return(list(
    bn = gen.discrete.bn(vars, parents),
    bn.fitted = gen.discrete.bn.fitted(vars, dims, parents, probs)))
}

bn.fitted.from.file = function(network) {
  source("networks_params/", network, ".R")
  return(gen.discrete.bn(vars, parents))
}

gen.hugin = function(bn.fitted, name, filename) {
  
  cat(file = filename, sep = "", append = FALSE, "net", "\n")
  cat(file = filename, sep = "", append = TRUE, "{", "\n")
  cat(file = filename, sep = "", append = TRUE, "  name = \"", name, "\";", "\n")
  cat(file = filename, sep = "", append = TRUE, "}", "\n")
  
  for (node in names(bn.fitted)) {
    cat(file = filename, sep = "", append = TRUE, "", "\n")
    cat(file = filename, sep = "", append = TRUE, "node ", node, "\n")
    cat(file = filename, sep = "", append = TRUE, "{", "\n")
    cat(file = filename, sep = "", append = TRUE, "  label = \"", node, "\";", "\n")
    cat(file = filename, sep = "", append = TRUE, "  states = (\"", paste(dimnames(bn.fitted[[node]]$prob)[[1]], collapse = "\" \""), "\");", "\n")
    cat(file = filename, sep = "", append = TRUE, "}", "\n")
  }
  
  format_probs_rec = function(probs.table, conds = c()) {
    
    lines = vector()
    dims = dim(probs.table)
    
    if (length(conds) + 1 == length(dims)) {
      
      from = 1
      if (length(conds) > 0)
        for (i in 1:length(conds))
          from = from + (conds[i] - 1) * prod(dims[setdiff(1:length(dims), 2:(i+1))])
      
      to = from + dims[1] - 1
      
      return(paste(" ", paste(formatC(probs.table[from:to], format="fg"), collapse = " "), " ", sep = ""))
      
    }
    
    for (i in 1:dims[length(conds) + 2]) {
      
      start = "("
      if (i > 1)
        start = paste(paste(rep(" ", length(conds)), collapse = ""), start, sep="")
      end = ")"
      
      tmp = format_probs_rec(probs.table, c(conds, i))
      tmp[1] = paste(start, tmp[1], sep = "")
      tmp[length(tmp)] = paste(tmp[length(tmp)], end, sep = "")
      
      lines = c(lines, tmp)
    }
    
    return(lines)
  }
  
  format_dims = function(dimnames) {
    
    lines = c()
    
    if(length(dimnames) > 0) {
      subdims = format_dims(dimnames[-1])
      for (dim in unlist(dimnames[1]))
        lines = c(lines, paste("\"", dim, "\" ", subdims, sep = ""))
    }
    
    return(lines)
  }
  
  for (node in names(bn.fitted)) {
    cat(file = filename, sep = "", append = TRUE, "", "\n")
    cat(file = filename, sep = "", append = TRUE, "potential (", node)
    parents = bn.fitted[[node]]$parents
    if (length(parents) > 0)
      cat(file = filename, sep = "", append = TRUE, " | ", paste(parents, collapse = " "))
    cat(file = filename, sep = "", append = TRUE, ")", "\n")
    cat(file = filename, sep = "", append = TRUE, "{", "\n")
    cat(file = filename, sep = "", append = TRUE, "  data = (", "\n")
    cat(file = filename, sep = "", append = TRUE, paste("  ",
                                                        paste(format_probs_rec(bn.fitted[[node]]$prob), format_dims(dimnames(bn.fitted[[node]]$prob)[-1]), sep = " % "),
                                                        "\n", collapse = "", sep = ""))
    cat(file = filename, sep = "", append = TRUE, "  );", "\n")
    cat(file = filename, sep = "", append = TRUE, "}", "\n")
  }
}

# Pasted from bnlearn::backend-score.R
arcs.to.be.added = function(amat, nodes, blacklist = NULL, whitelist = NULL,
                            arcs = TRUE) {
  
  .Call("hc_to_be_added",
        arcs = amat,
        blacklist = blacklist,
        whitelist = whitelist,
        nodes = nodes,
        convert = arcs,
        PACKAGE = "bnlearn")
  
}#ARCS.TO.BE.ADDED

learn.skeleton = function(params) {
  
  method = params$method
  target = params$target
  size = params$size
  rep = params$rep
  seed = params$seed
  test = params$test
  p = params$p
  alpha = params$alpha
  
  if (method != "none") {
    
    set.seed(seed)
    
    filename = paste(target, "_", size, "_", rep, sep="")
    
    training = get(load(paste("samples/", filename, "_training.rda", sep="")))
    order = get(load(paste("samples/", filename, "_order_", p, ".rda", sep="")))
    
    time = system.time((
      skeleton = switch(
        method,
        "mmpc" = mmpc(
          x = training[, order], test = test, test.args=list(power.rule=5, df.adjust=TRUE), alpha = alpha,
          optimized = FALSE, strict = FALSE),
        "mmpc-bt" = mmpc(
          x = training[, order], test = test, test.args=list(power.rule=5, df.adjust=TRUE), alpha = alpha,
          optimized = TRUE, strict = FALSE, undirected = TRUE),
        "pc" = pc(
          x = training[, order], test = test, test.args=list(power.rule=5, df.adjust=TRUE), alpha = alpha,
          undirected = TRUE),
        "rpc" = rpc(
          x = training[, order], test = test, test.args=list(power.rule=5, df.adjust=TRUE), alpha = alpha,
          optimized = FALSE, strict = FALSE, undirected = TRUE, nbr.join = "OR"),
#         "rpc" = rpc(
#           x = training[, order], test = test, test.args=list(power.rule=5, df.adjust=TRUE), alpha = alpha,
#           optimized = FALSE, strict = FALSE, undirected = TRUE,
#           pc.method = "mmpc", nbr.join = "OR"),
#         "rpc-and" = rpc(
#           x = training[, order], test = test, test.args=list(power.rule=5, df.adjust=TRUE), alpha = alpha,
#           optimized = FALSE, strict = FALSE, undirected = TRUE,
#           pc.method = "mmpc", nbr.join = "AND"),
#         "rpc2" = rpc(
#           x = training[, order], test = test, test.args=list(power.rule=5, df.adjust=TRUE), alpha = alpha,
#           optimized = FALSE, strict = FALSE, undirected = TRUE,
#           pc.method = "fdr.iapc", nbr.join = "OR"),
#         "rpc2-and" = rpc(
#           x = training[, order], test = test, test.args=list(power.rule=5, df.adjust=TRUE), alpha = alpha,
#           optimized = FALSE, strict = FALSE, undirected = TRUE,
#           pc.method = "fdr.iapc", nbr.join = "AND"),
        "hpc" = hpc(
          x = training[, order], test = test, test.args=list(power.rule=5, df.adjust=TRUE), alpha = alpha,
          optimized = FALSE, strict = FALSE, undirected = TRUE,
          nbr.join="AND", pc.method="inter.iapc"),
        "hpc-or" = hpc(
          x = training[, order], test = test, test.args=list(power.rule=5, df.adjust=TRUE), alpha = alpha,
          optimized = FALSE, strict = FALSE, undirected = TRUE,
          nbr.join="OR", pc.method="inter.iapc"),
        "fast-hpc" = hpc(
          x = training[, order], test = test, test.args=list(power.rule=5, df.adjust=TRUE), alpha = alpha,
          optimized = FALSE, strict = FALSE, undirected = TRUE,
          nbr.join="AND", pc.method="fast.iapc"),
        "hpc-fdr" = hpc(
          x = training[, order], test = test, test.args=list(power.rule=5, df.adjust=TRUE), alpha = alpha,
          optimized = FALSE, strict = FALSE, undirected = TRUE,
          nbr.join="AND", pc.method="fdr.iamb"),
        "hpc-fdr-or" = hpc(
          x = training[, order], test = test, test.args=list(power.rule=5, df.adjust=TRUE), alpha = alpha,
          optimized = FALSE, strict = FALSE, undirected = TRUE,
          nbr.join="OR", pc.method="fdr.iapc"),
        "hpc-fdr-bt" = hpc(
          x = training[, order], test = test, test.args=list(power.rule=5, df.adjust=TRUE), alpha = alpha,
          optimized = TRUE, strict = FALSE, undirected = TRUE,
          nbr.join="AND", pc.method="fdr.iapc"),
        "hpc.cached" = hpc.cached(
          x = training[, order], test = test, test.args=list(power.rule=5, df.adjust=TRUE), alpha = alpha,
          strict = FALSE, undirected = TRUE,
          nbr.join="AND", pc.method="inter.iapc"),
        "hpc.cached-fdr" = hpc.cached(
          x = training[, order], test = test, test.args=list(power.rule=5, df.adjust=TRUE), alpha = alpha,
          strict = FALSE, undirected = TRUE,
          nbr.join="AND", pc.method="fdr.iapc"),
        "iambfdr" = fdr.iamb(
          nbr.join="OR",
          x = training[, order], test = test, test.args=list(power.rule=5, df.adjust=TRUE), alpha = alpha,
          optimized = FALSE, strict = FALSE, undirected = TRUE),
        "iambfdr-and" = fdr.iamb(
          nbr.join="AND",
          x = training[, order], test = test, test.args=list(power.rule=5, df.adjust=TRUE), alpha = alpha,
          optimized = FALSE, strict = FALSE, undirected = TRUE),
        "iamb" = iamb(
          x = training[, order], test = test, test.args=list(power.rule=5, df.adjust=TRUE), alpha = alpha,
          optimized = FALSE, strict = FALSE, undirected = TRUE),
        "inter-iamb" = inter.iamb(
          x = training[, order], test = test, test.args=list(power.rule=5, df.adjust=TRUE), alpha = alpha,
          optimized = FALSE, strict = FALSE, undirected = TRUE),
        "fast-iamb" = fast.iamb(
          x = training[, order], test = test, test.args=list(power.rule=5, df.adjust=TRUE), alpha = alpha,
          optimized = FALSE, strict = FALSE, undirected = TRUE),
        "truedag" = skeleton(
          bn.net(get(load(paste("./networks/", target, ".rda", sep=""))))),
        stop("Unknown method : ", method)
      )))
    
    dir.create(paste("models/skeleton/", method, "/", test, "/", alpha, sep=""), recursive = TRUE, showWarnings = FALSE)
    
    save(skeleton, file=paste("models/skeleton/", method, "/", test, "/", alpha, "/", filename, "_p", p, "_skeleton.rda", sep=""))
    save(time, file=paste("models/skeleton/", method, "/", test, "/", alpha, "/", filename, "_p", p, "_time.rda", sep=""))
    
    if (conf.progress.tracking) {
      m = boost.mutex("bayes-benchmark")
      lock(m)
      cat(format(Sys.time(), "%Y.%m.%d_%H:%M:%S"), " skeleton ", target, " ", method, " ", test, " ", alpha, " ", size, " r", rep, " p", p, " - ", time["user.self"], "\n", file=progress.file, append=TRUE, sep="")
      unlock(m)
    }

  }

}#LEARN.SKELETON

learn.dag = function(params) {
  
  fromMethod = params$fromMethod
  method = params$method
  target = params$target
  size = params$size
  rep = params$rep
  seed = params$seed
  test = params$test
  p = params$p
  alpha = params$alpha
  
  set.seed(seed)
  
  filename = paste(target, "_", size, "_", rep, sep="")
  
  training = get(load(paste("samples/", filename, "_training.rda", sep="")))
  order = get(load(paste("samples/", filename, "_order_", p, ".rda", sep="")))
  if (fromMethod != "none")
    skeleton = get(load(paste("models/skeleton/", fromMethod, "/", test, "/", alpha, "/", filename, "_p", p, "_skeleton.rda", sep="")))
  
  time = system.time((
    dag = switch(method,
                 "tabu" = tabu(x = training[, order], start = NULL,
                               blacklist = if(fromMethod == "none") NULL else arcs.to.be.added(skeleton$arcs, names(skeleton$nodes)),
                               score = params$score, tabu = params$tabu, max.tabu = params$max.tabu,
                               optimized = TRUE),
                 "2p" = pdag2dag(x = skeleton2pdag(bn = skeleton, data = training[, order], strict = FALSE),
                                 ordering = names(training[, order]))
                 )
    ))
  
  dir.create(paste("models/dag/", method, "/", fromMethod, "/", test, "/", alpha, sep=""), recursive = TRUE, showWarnings = FALSE)
  
  save(dag, file=paste("models/dag/", method, "/", fromMethod, "/", test, "/", alpha, "/", filename, "_p", p, "_dag.rda", sep=""))
  save(time, file=paste("models/dag/", method, "/", fromMethod, "/", test, "/", alpha, "/", filename, "_p", p, "_time.rda", sep=""))
  
  if (conf.progress.tracking) {
    m = boost.mutex("bayes-benchmark")
    lock(m)
    cat(format(Sys.time(), "%Y.%m.%d_%H:%M:%S"), " dag ", target, " ", fromMethod, " ", method, " ", test, " ", alpha, " ", size, " r", rep, " p", p, " - ", time["user.self"], "\n", file=progress.file, append=TRUE, sep="")
    unlock(m)
  }
  
}#LEARN.DAG

gen.rep.bn.fit = function(bn, nb) {
  bn.rep = list()
  for (node in names(bn)) {
    for (i in 1:nb) {
      node.new = paste(node, i, sep="_")
      bn.rep[[node.new]] = bn[[node]]
      bn.rep[[node.new]]$node = node.new
      if (length(bn[[node]]$parents) > 0)
        bn.rep[[node.new]]$parents = paste(bn[[node]]$parents, i, sep="_")
      if (length(bn[[node]]$children) > 0)
        bn.rep[[node.new]]$children = paste(bn[[node]]$children, i, sep="_")
    }
  }
  bn.rep = structure(bn.rep, class = "bn.fit")
  return(bn.rep)
}

plot.fig.lines = function(res, x, y, seps, color = "red", pch = 3, lty = 1) {
  if (length(seps) > 0) {
    for (sep in seps[[1]]) {
      plot.fig.lines(res = res[res[, names(seps)[1]] == sep, ],
                     x = x[res[, names(seps)[1]] == sep],
                     y = y[res[, names(seps)[1]] == sep],
                     seps = seps[-1], color = color, pch = pch)
    }
  }
  else {
    means = aggregate(y, list(x), mean)
    xs = means[, 1]
    means = means[, 2]
    sds = aggregate(y, list(x), sd)[, 2]
    
    points(xs, means, pch = pch, col = color)
    lines(xs, means, type = "l", col = color, lwd = 1.5, lty = lty)
#     arrows(xs, means + sds, xs, means - sds, col = color, length=0.05, angle=90, code=3)
  }
}

boxplot.fig = function(x, y, xlab, ylab, title, color) {
  y = y[y != NA | y != Inf]
  x = x[y != NA | y != Inf]
  #  plot(aggregate(y, list(x), mean), pch = 16, xlab = xlab, ylab = paste(ylab, "% improvement"))
  #  lines(aggregate(y, list(x), mean), type = "l")
  boxplot(y ~ x,
          xlab = xlab,
          ylab = ylab,
          boxwex = 0.5)
  #          xlab="",
  #          ylab="",
  #          at = aggregate(bx, list(bx), mean)[, "x"],
  #          add = TRUE)
  title(title)
  grid(nx = NA, ny = NULL)
  points(aggregate(y, list(factor(x)), mean), pch = 16, col = color)
  lines(aggregate(y, list(factor(x)), mean), type = "l", col = color)
}

boxplot.factor.fig = function(x, y, xlab, ylab, title, color) {
  y = y[y != NA | y != Inf]
  x = x[y != NA | y != Inf]
  #  plot(aggregate(y, list(x), mean), pch = 16, xlab = xlab, ylab = paste(ylab, "% improvement"))
  #  lines(aggregate(y, list(x), mean), type = "l")
  boxplot(y ~ x,
          xlab = xlab,
          #          xlab="",
          ylab = "increase factor",
          #          ylab = "",
          border = color,
          boxwex = 0.5,
          range  = 0,
          ylim = c(min(1, min(ifelse(by == Inf, NA, by), na.rm=TRUE)), max(1, max(ifelse(by == Inf, NA, by), na.rm=TRUE)))
          #          at = aggregate(bx, list(bx), mean)[, "x"],
          #          add = TRUE)
          )
  title(title)
  grid(nx = NA, ny = NULL)
  lines(c(0, length(levels(factor(x))) + 1), c(1, 1), type = "l", lty = "solid", col = "red")
  points(aggregate(y, list(factor(x)), mean), pch = 16)
  lines(aggregate(y, list(factor(x)), mean), type = "l")
}
