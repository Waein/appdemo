package cn.byb.appdemo;

import cn.byb.appdemo.util.SeqIdUtil;
import com.google.common.collect.Lists;
import org.apache.commons.io.FileUtils;
import org.apache.commons.lang3.StringUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.BeansException;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.ApplicationContext;
import org.springframework.context.ApplicationContextAware;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.ImportResource;
import org.springframework.core.env.Environment;
import org.springframework.http.HttpStatus;
import org.springframework.scheduling.annotation.EnableScheduling;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Controller;
import org.springframework.util.CollectionUtils;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseBody;

import javax.servlet.http.HttpServletResponse;
import java.io.File;
import java.util.Collection;
import java.util.List;

/**
 * Created by byb on 24/5/6.
 */
@Controller
@Configuration
@EnableScheduling
@SpringBootApplication
@ImportResource(locations = {"classpath*:app.xml", "classpath*:metrics.xml"})
public class AppMain implements ApplicationContextAware {

    private final static Logger log = LoggerFactory.getLogger(AppMain.class);

    private final static int retention = 86400 * 1000 * 3;

    private final static List<Runnable> preHaltTasks = Lists.newArrayList();

    private static ApplicationContext context;

    public static ApplicationContext context() {
        return context;
    }

    private static boolean halt = false;

    @Autowired
    Environment environment;

    @Value("${server.tomcat.accesslog.enabled}")
    boolean accessLogEnabled;

    @Value("${server.tomcat.accesslog.directory}")
    String accessLogPath;

    @RequestMapping("/ok.htm")
    @ResponseBody
    String ok(@RequestParam(defaultValue = "false") String down, final HttpServletResponse response) {
        if (halt) {
            response.setStatus(HttpStatus.SERVICE_UNAVAILABLE.value());
            return "halting";
        }
        if (Boolean.parseBoolean(down) && !halt) {
            log.warn("prehalt initiated and further /ok.htm request will return with status 503");
            halt = true;
            for (final Runnable r : preHaltTasks) {
                try {
                    r.run();
                } catch (Exception e) {
                    log.error("prehalt task failed", e);
                }
            }
        }
        return "ok";
    }

    @RequestMapping("/error_log_test")
    @ResponseBody
    String errorLogTest() {
        String seqId = SeqIdUtil.getUniqIDHash();
        String partner = seqId.substring(0, 8);
        try {
            System.out.println(3 / 0);
        } catch (Exception ex) {
            log.error(String.format("BBLOG://v1/?seqid=%s&partner=%s&customErrorMessage=%s&placeholder=error_stack_is", seqId, partner, "error occur,"), ex);
        }
        return "error_log_test";
    }


    @RequestMapping("/")
    @ResponseBody
    String home() {
        return "ok";
    }

    @Scheduled(cron = " 0 5 0 * * ? ") //runs every day 00:05:00
    public void accessLogCleaner() {
        if (accessLogEnabled) {
            if (StringUtils.isEmpty(accessLogPath)) {
                return;
            }
            log.warn("now cleaning access log in dir {}", accessLogPath);
            final Collection<File> files = FileUtils.listFiles(new File(accessLogPath), new String[]{"log"}, false);
            if (CollectionUtils.isEmpty(files)) {
                log.warn("no log found and nothing to do");
                return;
            }
            for (final File f : files) {
                if (f.getName().startsWith("access_log") && System.currentTimeMillis() - f.lastModified() > retention) {
                    final boolean b = f.delete();
                    log.warn("deleting old log {} ... {}", f.getName(), b);
                }
            }
        }
    }

    public static void addPreHaltTask(final Runnable runnable) {
        if (runnable != null) {
            preHaltTasks.add(runnable);
        }
    }

    public static void main(String[] args) throws Exception {
        try {
            SpringApplication.run(AppMain.class, args);
        } catch (Throwable e) {
            e.printStackTrace();
            throw e;
        }
        log.info("appdemo started 😘");
    }

    @Override
    public void setApplicationContext(ApplicationContext applicationContext) throws BeansException {
        if (AppMain.context == null) {
            AppMain.context = applicationContext;
        }
    }
}

